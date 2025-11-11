-- ============================================================================
-- Migration: Update tenants structure and add tenant_contacts, tenant_emr_configs
-- Implements changes from updated additional_schema.sql
-- ============================================================================

-- ============================================================================
-- NEW ENUMS
-- ============================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tenant_status') THEN
    CREATE TYPE tenant_status AS ENUM ('trialing','active','suspended','closed');
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tenant_contact_role') THEN
    CREATE TYPE tenant_contact_role AS ENUM (
      'owner',       -- account owner / decision maker
      'admin',       -- operational admin
      'billing',     -- finance / accounts
      'technical',   -- IT / integration contact
      'support',     -- CS contact
      'other'
    );
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'emr_type') THEN
    CREATE TYPE emr_type AS ENUM ('none','openmrs','other');
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- DROP AND RECREATE TENANTS TABLE WITH NEW STRUCTURE
-- ============================================================================

-- Drop dependent tables temporarily (will be recreated)
DROP TABLE IF EXISTS handover_events CASCADE;
DROP TABLE IF EXISTS bot_intents CASCADE;
DROP TABLE IF EXISTS message_templates CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS appointment_reminders CASCADE;
DROP TABLE IF EXISTS contacts CASCADE;
DROP TABLE IF EXISTS phone_numbers CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;

-- Recreate tenants with new structure
CREATE TABLE "public"."tenants" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Stable business key for URLs, scripts, configs
  "slug" TEXT NOT NULL UNIQUE,

  -- Customer identity
  "name" TEXT NOT NULL,
  "status" tenant_status NOT NULL DEFAULT 'trialing',
  "plan_code" TEXT NOT NULL DEFAULT 'free',

  -- Primary account owner
  "owner_name" TEXT NOT NULL,
  "owner_email" TEXT NOT NULL,

  -- Billing contact
  "billing_email" TEXT NOT NULL,
  "billing_phone" TEXT,

  -- Support contact
  "support_email" TEXT,
  "support_phone" TEXT,

  -- Location / timezone
  "country_code" TEXT,
  "city" TEXT,
  "timezone" TEXT NOT NULL DEFAULT 'Asia/Karachi',

  -- Integration links
  "auth_owner_user_id" UUID,
  "billing_external_id" TEXT,

  -- Soft delete
  "voided" BOOLEAN NOT NULL DEFAULT FALSE,

  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for tenants
CREATE INDEX idx_tenants_status ON tenants(status);
CREATE INDEX idx_tenants_auth_owner ON tenants(auth_owner_user_id);
CREATE INDEX idx_tenants_billing_email ON tenants(billing_email);

-- ============================================================================
-- CREATE TENANT_CONTACTS TABLE
-- ============================================================================

CREATE TABLE "public"."tenant_contacts" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "tenant_id" UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

  "role" tenant_contact_role NOT NULL,
  "name" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "phone" TEXT,
  "notes" TEXT,

  "is_primary" BOOLEAN NOT NULL DEFAULT FALSE,
  "voided" BOOLEAN NOT NULL DEFAULT FALSE,

  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for tenant_contacts
CREATE INDEX idx_tenant_contacts_tenant_role
  ON tenant_contacts(tenant_id, role)
  WHERE voided = false;

-- At most one primary per role per tenant
CREATE UNIQUE INDEX uq_tenant_contacts_primary_role
  ON tenant_contacts(tenant_id, role)
  WHERE is_primary = true AND voided = false;

-- ============================================================================
-- CREATE TENANT_EMR_CONFIGS TABLE
-- ============================================================================

CREATE TABLE "public"."tenant_emr_configs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "tenant_id" UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

  "emr_type" emr_type NOT NULL DEFAULT 'none',
  "is_active" BOOLEAN NOT NULL DEFAULT TRUE,

  -- EMR + workflow + AI config as one dedicated blob
  "emr_config" JSONB NOT NULL DEFAULT '{}'::jsonb,

  "voided" BOOLEAN NOT NULL DEFAULT FALSE,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Index for tenant_emr_configs
CREATE INDEX idx_tenant_emr_configs_tenant
  ON tenant_emr_configs(tenant_id)
  WHERE voided = false AND is_active = true;

-- ============================================================================
-- RECREATE PHONE_NUMBERS TABLE
-- ============================================================================

CREATE TABLE "public"."phone_numbers" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "tenant_id" UUID NOT NULL REFERENCES "tenants"("id") ON DELETE CASCADE,
  "wa_phone_number_id" TEXT NOT NULL,
  "waba_id" TEXT,
  "is_active" BOOLEAN NOT NULL DEFAULT TRUE,
  "auto_handover_on_echo" BOOLEAN NOT NULL DEFAULT TRUE,
  "echo_handover_mute_seconds" INTEGER,
  "working_hours_override" JSONB,
  "voided" BOOLEAN NOT NULL DEFAULT FALSE,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE ("tenant_id", "wa_phone_number_id")
);

CREATE INDEX idx_phone_numbers_tenant ON phone_numbers(tenant_id);

-- ============================================================================
-- RECREATE CONTACTS TABLE
-- ============================================================================

CREATE TABLE "public"."contacts" (
  "id" BIGSERIAL PRIMARY KEY,
  "tenant_id" UUID NOT NULL REFERENCES "tenants"("id") ON DELETE CASCADE,
  "phone_number_id" UUID REFERENCES "phone_numbers"("id"),
  "wa_id" NUMERIC NOT NULL,
  "profile_name" TEXT,
  "tags" TEXT[] NOT NULL DEFAULT '{}',
  "in_chat" BOOLEAN NOT NULL DEFAULT FALSE,
  "assigned_to" TEXT,
  "unread_count" INTEGER NOT NULL DEFAULT 0,
  "last_message_at" TIMESTAMP WITH TIME ZONE,
  "last_message_received_at" TIMESTAMP WITH TIME ZONE,
  "opted_out" BOOLEAN NOT NULL DEFAULT FALSE,
  "voided" BOOLEAN NOT NULL DEFAULT FALSE,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE ("tenant_id", "wa_id")
);

CREATE INDEX idx_contacts_tenant_wa ON contacts(tenant_id, wa_id);
CREATE INDEX idx_contacts_tenant_last ON contacts(tenant_id, last_message_at DESC);
CREATE INDEX idx_contacts_profile_trgm ON contacts USING gin (profile_name gin_trgm_ops);
CREATE INDEX idx_contacts_wa_id ON contacts(wa_id);  -- For message lookups

-- ============================================================================
-- RECREATE MESSAGES TABLE
-- ============================================================================

CREATE TABLE "public"."messages" (
  "id" BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  "tenant_id" UUID NOT NULL REFERENCES "tenants"("id") ON DELETE CASCADE,
  "chat_id" NUMERIC NOT NULL,  -- Phone number: can be user (contacts) OR system (phone_numbers)
  "message" JSONB NOT NULL,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "media_url" TEXT,
  "wam_id" CHARACTER VARYING NOT NULL,
  "delivered_at" TIMESTAMP WITH TIME ZONE,
  "read_at" TIMESTAMP WITH TIME ZONE,
  "sent_at" TIMESTAMP WITH TIME ZONE,
  "is_received" BOOLEAN NOT NULL DEFAULT FALSE,
  "read_by_user_at" TIMESTAMP WITH TIME ZONE,
  "failed_at" TIMESTAMP WITH TIME ZONE,
  CONSTRAINT messages_wam_id_key UNIQUE (wam_id)
);

CREATE INDEX idx_messages_chat_time ON messages(chat_id, created_at DESC);
CREATE INDEX idx_messages_tenant ON messages(tenant_id);

-- ============================================================================
-- RECREATE CONVERSATIONS TABLE
-- ============================================================================

CREATE TABLE "public"."conversations" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "tenant_id" UUID NOT NULL REFERENCES "tenants"("id") ON DELETE CASCADE,
  "phone_number_id" UUID REFERENCES "phone_numbers"("id"),
  "contact_wa_id" NUMERIC NOT NULL,  -- References contacts.wa_id (not FK due to composite key)
  "status" conversation_mode NOT NULL DEFAULT 'bot',
  "assigned_to_label" TEXT,
  "mute_bot_until" TIMESTAMP WITH TIME ZONE,
  "session_expires_at" TIMESTAMP WITH TIME ZONE,
  "active_flow_key" TEXT,
  "flow_state" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "flow_status" TEXT NOT NULL DEFAULT 'idle' CHECK ("flow_status" IN ('idle','running','paused','completed','failed')),
  "last_user_msg_at" TIMESTAMP WITH TIME ZONE,
  "last_agent_msg_at" TIMESTAMP WITH TIME ZONE,
  "voided" BOOLEAN NOT NULL DEFAULT FALSE,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE ("tenant_id", "contact_wa_id", "phone_number_id")
  -- NO FK constraint: contact_wa_id references contacts(wa_id) but wa_id is not unique alone
);

CREATE INDEX idx_conversations_tenant_number_status ON conversations(tenant_id, phone_number_id, status);
CREATE INDEX idx_conversations_tenant_updated ON conversations(tenant_id, updated_at DESC);

-- ============================================================================
-- RECREATE BOT_INTENTS TABLE
-- ============================================================================

CREATE TABLE "public"."bot_intents" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "tenant_id" UUID NOT NULL REFERENCES "tenants"("id") ON DELETE CASCADE,
  "key" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "kind" TEXT NOT NULL DEFAULT 'custom' CHECK ("kind" IN ('appointment','general','support','custom')),
  "definition" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "phrase" TEXT NOT NULL,
  "is_regex" BOOLEAN NOT NULL DEFAULT FALSE,
  "locale" TEXT DEFAULT 'en',
  "priority" INTEGER NOT NULL DEFAULT 100,
  "active" BOOLEAN NOT NULL DEFAULT TRUE,
  "voided" BOOLEAN NOT NULL DEFAULT FALSE,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE ("tenant_id", "key", "phrase", "locale")
);

CREATE INDEX idx_bot_intents_tenant_active ON bot_intents(tenant_id, active);
CREATE INDEX idx_bot_intents_phrase_trgm ON bot_intents USING gin (phrase gin_trgm_ops);
CREATE INDEX idx_bot_intents_tenant_key ON bot_intents(tenant_id, key, active);

-- ============================================================================
-- RECREATE HANDOVER_EVENTS TABLE
-- ============================================================================

CREATE TABLE "public"."handover_events" (
  "id" BIGSERIAL PRIMARY KEY,
  "conversation_id" UUID NOT NULL REFERENCES "conversations"("id") ON DELETE CASCADE,
  "action" TEXT NOT NULL CHECK ("action" IN ('request','grant','release','timeout','auto_close')),
  "actor" JSONB NOT NULL,
  "at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- RECREATE APPOINTMENT REMINDERS TABLE
-- ============================================================================

CREATE TABLE "public"."appointment_reminders" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "tenant_id" UUID NOT NULL REFERENCES "tenants"("id") ON DELETE CASCADE,
  "wa_id" NUMERIC NOT NULL,  -- References contacts.wa_id (phone number)
  "send_by" CHARACTER VARYING(20) NOT NULL,
  "cancel_by" CHARACTER VARYING(20),
  "status" CHARACTER VARYING(50) NOT NULL,
  "template_id" CHARACTER VARYING NOT NULL,
  "patient_response" TEXT,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "appointment_uuid" UUID
);

CREATE INDEX idx_appointment_reminders_cancel_by ON appointment_reminders(cancel_by);
CREATE INDEX idx_appointment_reminders_created_at ON appointment_reminders(created_at);
CREATE INDEX idx_appointment_reminders_send_by ON appointment_reminders(send_by);
CREATE INDEX idx_appointment_reminders_status ON appointment_reminders(status);
CREATE INDEX idx_appointment_reminders_wa_id ON appointment_reminders(wa_id);
CREATE INDEX idx_appointment_reminders_tenant ON appointment_reminders(tenant_id);

-- ============================================================================
-- RECREATE TRIGGER FUNCTIONS
-- ============================================================================

-- Touch contact on message (chat_id is wa_id/phone number)
CREATE OR REPLACE FUNCTION fn_touch_contact_on_message()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Update contact by wa_id (phone number)
  UPDATE contacts c
     SET last_message_at = new.created_at,
         last_message_received_at = CASE WHEN new.is_received THEN new.created_at ELSE c.last_message_received_at END,
         unread_count = CASE WHEN new.is_received THEN COALESCE(c.unread_count,0) + 1 ELSE c.unread_count END
   WHERE c.wa_id = new.chat_id
     AND c.voided = false;
  RETURN new;
END $$;

-- Touch session window (chat_id is wa_id/phone number)
CREATE OR REPLACE FUNCTION fn_touch_session_window()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE c_rec contacts;
BEGIN
  IF new.is_received THEN
    -- Find contact by wa_id (phone number)
    SELECT * INTO c_rec FROM contacts WHERE wa_id = new.chat_id AND voided = false;
    IF FOUND THEN
      INSERT INTO conversations (
        tenant_id, phone_number_id, contact_wa_id,
        session_expires_at, last_user_msg_at, updated_at
      )
      VALUES (
        c_rec.tenant_id, c_rec.phone_number_id, c_rec.wa_id,
        new.created_at + interval '24 hours', new.created_at, now()
      )
      ON CONFLICT (tenant_id, contact_wa_id, phone_number_id) DO UPDATE
        SET session_expires_at = excluded.session_expires_at,
            last_user_msg_at   = excluded.last_user_msg_at,
            updated_at         = now();
    END IF;
  END IF;
  RETURN new;
END $$;

-- Pick intent on inbound (chat_id is wa_id/phone number)
CREATE OR REPLACE FUNCTION fn_pick_intent_on_inbound()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE c_rec contacts; msg text; chosen_key text;
BEGIN
  IF NOT new.is_received THEN RETURN new; END IF;

  -- Find contact by wa_id (phone number)
  SELECT * INTO c_rec FROM contacts WHERE wa_id = new.chat_id AND voided = false;
  IF NOT FOUND THEN RETURN new; END IF;

  msg := lower(get_msg_text(new.message));

  SELECT bi.key INTO chosen_key
    FROM bot_intents bi
   WHERE bi.tenant_id = c_rec.tenant_id
     AND bi.active AND bi.voided = false
     AND (
          (bi.is_regex = false AND position(lower(bi.phrase) IN msg) > 0)
       OR (bi.is_regex = true  AND msg ~* bi.phrase)
     )
   ORDER BY bi.priority DESC, bi.created_at ASC
   LIMIT 1;

  UPDATE conversations
     SET active_flow_key = COALESCE(chosen_key, active_flow_key),
         flow_status     = CASE WHEN chosen_key IS NOT NULL THEN 'running' ELSE flow_status END,
         updated_at      = now()
   WHERE tenant_id = c_rec.tenant_id
     AND phone_number_id = c_rec.phone_number_id
     AND contact_wa_id = c_rec.wa_id
     AND voided = false;

  RETURN new;
END $$;

-- Echo handover (chat_id is wa_id/phone number)
CREATE OR REPLACE FUNCTION fn_echo_handover_min_safe()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  ts timestamptz := COALESCE(new.created_at, now());
  mute_seconds int;
  c_rec contacts;
  p_rec phone_numbers;
BEGIN
  -- outbound only
  IF new.is_received THEN RETURN new; END IF;

  -- detect echo flag in payload
  IF NOT (COALESCE((new.message->>'origin')='agent_app',false)
          OR COALESCE((new.message->>'echo')::boolean,false)) THEN
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
END $$;

-- ============================================================================
-- RECREATE TRIGGERS
-- ============================================================================

CREATE TRIGGER trg_msg_10_touch_contact
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_touch_contact_on_message();

CREATE TRIGGER trg_msg_20_touch_session
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_touch_session_window();

CREATE TRIGGER trg_msg_30_pick_intent
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_pick_intent_on_inbound();

CREATE TRIGGER trg_msg_40_echo_handover
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_echo_handover_min_safe();

CREATE TRIGGER appointment_reminders_update_updated_at
BEFORE UPDATE ON appointment_reminders
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_emr_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE phone_numbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE handover_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_reminders ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Tenants
DROP POLICY IF EXISTS tenants_select ON tenants;
CREATE POLICY tenants_select ON tenants
  FOR SELECT USING (id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);

DROP POLICY IF EXISTS tenants_update ON tenants;
CREATE POLICY tenants_update ON tenants
  FOR UPDATE USING (id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Tenant contacts
DROP POLICY IF EXISTS tn_select_tenant_contacts ON tenant_contacts;
CREATE POLICY tn_select_tenant_contacts ON tenant_contacts
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);

DROP POLICY IF EXISTS tn_modify_tenant_contacts ON tenant_contacts;
CREATE POLICY tn_modify_tenant_contacts ON tenant_contacts
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Tenant EMR configs
DROP POLICY IF EXISTS tn_select_emr_configs ON tenant_emr_configs;
CREATE POLICY tn_select_emr_configs ON tenant_emr_configs
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);

DROP POLICY IF EXISTS tn_modify_emr_configs ON tenant_emr_configs;
CREATE POLICY tn_modify_emr_configs ON tenant_emr_configs
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Phone numbers
DROP POLICY IF EXISTS tn_select_phone_numbers ON phone_numbers;
CREATE POLICY tn_select_phone_numbers ON phone_numbers
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);

DROP POLICY IF EXISTS tn_modify_phone_numbers ON phone_numbers;
CREATE POLICY tn_modify_phone_numbers ON phone_numbers
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Contacts
DROP POLICY IF EXISTS tn_select_contacts ON contacts;
CREATE POLICY tn_select_contacts ON contacts
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);

DROP POLICY IF EXISTS tn_modify_contacts ON contacts;
CREATE POLICY tn_modify_contacts ON contacts
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Conversations
DROP POLICY IF EXISTS tn_select_conversations ON conversations;
CREATE POLICY tn_select_conversations ON conversations
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);

DROP POLICY IF EXISTS tn_modify_conversations ON conversations;
CREATE POLICY tn_modify_conversations ON conversations
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Bot intents
DROP POLICY IF EXISTS tn_select_bot_intents ON bot_intents;
CREATE POLICY tn_select_bot_intents ON bot_intents
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);

DROP POLICY IF EXISTS tn_modify_bot_intents ON bot_intents;
CREATE POLICY tn_modify_bot_intents ON bot_intents
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Messages (simple tenant isolation)
DROP POLICY IF EXISTS tn_select_messages ON messages;
CREATE POLICY tn_select_messages ON messages
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

DROP POLICY IF EXISTS tn_modify_messages ON messages;
CREATE POLICY tn_modify_messages ON messages
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Handover events
DROP POLICY IF EXISTS tn_select_handover_events ON handover_events;
CREATE POLICY tn_select_handover_events ON handover_events
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM conversations cv
              JOIN contacts c ON c.wa_id = cv.contact_wa_id
            WHERE cv.id = handover_events.conversation_id
              AND cv.tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','')
              AND cv.voided = false)
  );

DROP POLICY IF EXISTS tn_modify_handover_events ON handover_events;
CREATE POLICY tn_modify_handover_events ON handover_events
  FOR ALL USING (
    EXISTS (SELECT 1 FROM conversations cv
              JOIN contacts c ON c.wa_id = cv.contact_wa_id
            WHERE cv.id = handover_events.conversation_id
              AND cv.tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM conversations cv
              JOIN contacts c ON c.wa_id = cv.contact_wa_id
            WHERE cv.id = handover_events.conversation_id
              AND cv.tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  );

-- Appointment reminders (simple tenant isolation)
DROP POLICY IF EXISTS tn_select_appointment_reminders ON appointment_reminders;
CREATE POLICY tn_select_appointment_reminders ON appointment_reminders
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

DROP POLICY IF EXISTS tn_modify_appointment_reminders ON appointment_reminders;
CREATE POLICY tn_modify_appointment_reminders ON appointment_reminders
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- ============================================================================
-- GRANTS
-- ============================================================================

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."appointment_reminders" TO "anon";
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."appointment_reminders" TO "authenticated";
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."appointment_reminders" TO "service_role";

-- ============================================================================
-- REALTIME PUBLICATION
-- ============================================================================

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE contacts;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;
END $$;
