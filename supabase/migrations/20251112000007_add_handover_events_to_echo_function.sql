-- Migration: Update echo handover function to create handover_events entries
-- Date: 2025-11-12
-- Reasoning: Audit trail for automatic handovers when agent/coexistence messages are sent

-- ============================================================================
-- Update fn_echo_handover_min_safe to create handover_events
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_echo_handover_min_safe()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  ts timestamptz := COALESCE(new.created_at, now());
  mute_seconds int;
  c_rec contacts;
  p_rec phone_numbers;
  conv_id uuid;
  actor_data jsonb;
BEGIN
  -- outbound only
  IF new.is_received THEN RETURN new; END IF;

  -- Check if message is from agent or coexistence (WhatsApp mobile)
  IF new.sender_type NOT IN ('agent', 'coexistence') THEN
    RETURN new;
  END IF;

  -- resolve settings via contact -> phone_number (find contact by wa_id)
  SELECT * INTO c_rec FROM contacts WHERE wa_id = new.chat_id AND voided = false;
  IF NOT FOUND THEN RETURN new; END IF;

  SELECT * INTO p_rec FROM phone_numbers WHERE id = c_rec.phone_number_id AND voided = false;

  IF COALESCE(p_rec.auto_handover_on_echo, true) IS FALSE THEN
    RETURN new;
  END IF;

  SELECT COALESCE(p_rec.echo_handover_mute_seconds, 86400)
    INTO mute_seconds;
  IF mute_seconds IS NULL THEN RETURN new; END IF;

  -- Build actor data based on sender_type
  actor_data := jsonb_build_object(
    'type', new.sender_type,
    'message_id', new.id,
    'timestamp', ts
  );

  -- upsert conversation, set human + extend mute, RETURNING id for handover_event
  INSERT INTO conversations (tenant_id, phone_number_id, contact_wa_id, status, mute_bot_until, last_agent_msg_at, updated_at)
  VALUES (c_rec.tenant_id, c_rec.phone_number_id, c_rec.wa_id, 'human', ts + (mute_seconds || ' seconds')::interval, ts, now())
  ON CONFLICT (tenant_id, contact_wa_id, phone_number_id) DO UPDATE
    SET status          = 'human',
        mute_bot_until  = GREATEST(conversations.mute_bot_until, excluded.mute_bot_until),
        last_agent_msg_at = ts,
        updated_at      = now()
  RETURNING id INTO conv_id;

  -- Insert handover event for audit trail
  -- Always log the event since mute_bot_until is extended on each agent/coexistence message
  IF conv_id IS NOT NULL THEN
    INSERT INTO handover_events (conversation_id, action, actor, at)
    VALUES (conv_id, 'grant', actor_data, ts);
  END IF;

  -- optional UI hint (updated to use 'Agent App' as text)
  UPDATE contacts
     SET in_chat = true,
         assigned_to = COALESCE(assigned_to, 'Agent App')
   WHERE wa_id = c_rec.wa_id AND voided = false;

  RETURN new;
END
$function$;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON FUNCTION public.fn_echo_handover_min_safe() IS
'Automatically switches conversation to human mode when agent or coexistence message is detected. Creates handover_events entry for audit trail. Uses sender_type column for better performance.';
