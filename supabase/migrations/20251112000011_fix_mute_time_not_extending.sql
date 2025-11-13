-- Migration: Fix mute_bot_until to only set once, not extend on every message
-- Date: 2025-11-12
-- Reasoning: Handover mute time should countdown from first agent message, not keep resetting

-- ============================================================================
-- Update fn_echo_handover_min_safe to fix mute_bot_until logic
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
  existing_mute timestamptz;
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

  -- Build actor data
  actor_data := jsonb_build_object(
    'type', new.sender_type,
    'message_id', new.id
  );

  -- Check if conversation already exists and get current mute_bot_until
  SELECT id, mute_bot_until INTO conv_id, existing_mute
  FROM conversations
  WHERE tenant_id = c_rec.tenant_id
    AND contact_wa_id = c_rec.wa_id
    AND phone_number_id = c_rec.phone_number_id;

  -- Upsert conversation
  IF conv_id IS NULL THEN
    -- New conversation: Set mute_bot_until
    INSERT INTO conversations (tenant_id, phone_number_id, contact_wa_id, status, mute_bot_until, last_agent_msg_at, updated_at)
    VALUES (c_rec.tenant_id, c_rec.phone_number_id, c_rec.wa_id, 'human', ts + (mute_seconds || ' seconds')::interval, ts, now())
    RETURNING id INTO conv_id;

    -- Log handover event for new conversation
    INSERT INTO handover_events (conversation_id, action, actor, at)
    VALUES (conv_id, 'grant', actor_data, ts);
  ELSE
    -- Existing conversation: Only extend mute if expired or about to expire (within 5 minutes)
    -- Otherwise, just update last_agent_msg_at and status without extending mute time
    IF existing_mute IS NULL OR existing_mute < (ts + interval '5 minutes') THEN
      -- Mute expired or expiring soon - extend it and log new handover
      UPDATE conversations
      SET status = 'human',
          mute_bot_until = ts + (mute_seconds || ' seconds')::interval,
          last_agent_msg_at = ts,
          updated_at = now()
      WHERE id = conv_id;

      -- Log handover event only when extending mute
      INSERT INTO handover_events (conversation_id, action, actor, at)
      VALUES (conv_id, 'grant', actor_data, ts);
    ELSE
      -- Mute still active - just update last_agent_msg_at, keep existing mute time
      UPDATE conversations
      SET status = 'human',
          last_agent_msg_at = ts,
          updated_at = now()
      WHERE id = conv_id;
      -- No handover event - conversation already in human mode
    END IF;
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
'Automatically switches conversation to human mode when agent or coexistence message is detected. Only extends mute_bot_until if expired or expiring soon (within 5 minutes), otherwise keeps original mute time. Creates handover_events only when mute is extended.';
