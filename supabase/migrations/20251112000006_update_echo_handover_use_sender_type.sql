-- Migration: Update echo handover function to use sender_type instead of message JSONB
-- Date: 2025-11-12
-- Reasoning: Cleaner, faster, and more maintainable than parsing JSONB

-- ============================================================================
-- Update fn_echo_handover_min_safe to use sender_type
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
BEGIN
  -- outbound only
  IF new.is_received THEN RETURN new; END IF;

  -- Check if message is from agent or coexistence (WhatsApp mobile)
  -- Replaced: JSONB parsing (message->>'origin' or message->>'echo')
  -- With: sender_type column check (cleaner, faster, type-safe)
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

  -- upsert conversation, set human + extend mute
  INSERT INTO conversations (tenant_id, phone_number_id, contact_wa_id, status, mute_bot_until, last_agent_msg_at, updated_at)
  VALUES (c_rec.tenant_id, c_rec.phone_number_id, c_rec.wa_id, 'human', ts + (mute_seconds || ' seconds')::interval, ts, now())
  ON CONFLICT (tenant_id, contact_wa_id, phone_number_id) DO UPDATE
    SET status          = 'human',
        mute_bot_until  = GREATEST(conversations.mute_bot_until, excluded.mute_bot_until),
        last_agent_msg_at = ts,
        updated_at      = now();

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
'Automatically switches conversation to human mode when agent or coexistence message is detected. Uses sender_type column instead of JSONB parsing for better performance.';
