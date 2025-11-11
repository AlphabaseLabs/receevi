-- ============================================================================
-- Migration: Add Multi-tenant Features
-- This migration adds tenant isolation, conversations, and bot intent system
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_mode') THEN
    CREATE TYPE conversation_mode AS ENUM ('bot','handover_pending','human','closed');
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- NEW TABLES
-- ============================================================================

-- Tenants table
CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "summary" TEXT,
    "website" TEXT,
    "email" TEXT,
    "phone_main" TEXT,
    "phone_alt" TEXT,
    "address_line1" TEXT,
    "address_line2" TEXT,
    "city" TEXT,
    "region" TEXT,
    "postal_code" TEXT,
    "country" TEXT,
    "timezone" TEXT NOT NULL DEFAULT 'Asia/Karachi',
    "working_hours" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "emergency_contacts" JSONB NOT NULL DEFAULT '[]'::jsonb,
    "languages" TEXT[] NOT NULL DEFAULT '{en}',
    "retention_days" INTEGER DEFAULT 365,
    "echo_handover_mute_seconds" INTEGER NOT NULL DEFAULT 86400,
    "config" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "voided" BOOLEAN NOT NULL DEFAULT FALSE,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Phone numbers table
CREATE TABLE IF NOT EXISTS "public"."phone_numbers" (
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

-- Conversations table
-- Note: contact_id will reference contacts.wa_id (which will be TEXT after migration)
CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL REFERENCES "tenants"("id") ON DELETE CASCADE,
    "phone_number_id" UUID REFERENCES "phone_numbers"("id"),
    "contact_id" TEXT NOT NULL,
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
    UNIQUE ("tenant_id", "contact_id", "phone_number_id")
);

-- Update existing message_template table to support multi-tenancy
-- Add new columns to existing message_template table
ALTER TABLE "public"."message_template" ADD COLUMN IF NOT EXISTS "tenant_id" UUID REFERENCES "tenants"("id") ON DELETE CASCADE;
ALTER TABLE "public"."message_template" ADD COLUMN IF NOT EXISTS "body" TEXT;
ALTER TABLE "public"."message_template" ADD COLUMN IF NOT EXISTS "voided" BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE "public"."message_template" ADD COLUMN IF NOT EXISTS "previous_category" TEXT;
ALTER TABLE "public"."message_template" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();

-- Bot intents table
CREATE TABLE IF NOT EXISTS "public"."bot_intents" (
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

-- Handover events table
CREATE TABLE IF NOT EXISTS "public"."handover_events" (
    "id" BIGSERIAL PRIMARY KEY,
    "conversation_id" UUID NOT NULL REFERENCES "conversations"("id") ON DELETE CASCADE,
    "action" TEXT NOT NULL CHECK ("action" IN ('request','grant','release','timeout','auto_close')),
    "actor" JSONB NOT NULL,
    "at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- MODIFY EXISTING TABLES
-- ============================================================================

-- Add new columns to contacts table
ALTER TABLE "public"."contacts" ADD COLUMN IF NOT EXISTS "tenant_id" UUID REFERENCES "tenants"("id") ON DELETE CASCADE;
ALTER TABLE "public"."contacts" ADD COLUMN IF NOT EXISTS "phone_number_id" UUID REFERENCES "phone_numbers"("id");
ALTER TABLE "public"."contacts" ADD COLUMN IF NOT EXISTS "opted_out" BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE "public"."contacts" ADD COLUMN IF NOT EXISTS "voided" BOOLEAN NOT NULL DEFAULT FALSE;

-- Change wa_id type from NUMERIC to TEXT (if needed for multi-tenant)
-- Note: This requires data migration, handle carefully in production
DO $$
BEGIN
    -- Check if wa_id is NUMERIC type
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'contacts'
        AND column_name = 'wa_id'
        AND data_type = 'numeric'
    ) THEN
        -- Drop RLS policies that depend on wa_id
        DROP POLICY IF EXISTS "Enable select for admin users and agent users to their contacts on contacts" ON contacts;
        DROP POLICY IF EXISTS "Enable update for admin users and agent users to their contacts on contacts" ON contacts;
        DROP POLICY IF EXISTS "Enable insert for admin users only on contacts" ON contacts;
        DROP POLICY IF EXISTS "Enable delete for admin users only on contacts" ON contacts;
        DROP POLICY IF EXISTS "Enable select for admin users and agent users to their contacts on messages" ON messages;
        DROP POLICY IF EXISTS "Enable update for admin users and agent users to their contacts on messages" ON messages;
        DROP POLICY IF EXISTS "Enable insert for admin users and agent users to their contacts on messages" ON messages;
        DROP POLICY IF EXISTS "Enable delete for admin users only on messages" ON messages;

        -- Drop dependent foreign key constraints
        ALTER TABLE "public"."appointment_reminders" DROP CONSTRAINT IF EXISTS "appointment_reminders_wa_id_fkey";

        -- Drop the primary key constraint
        ALTER TABLE "public"."contacts" DROP CONSTRAINT IF EXISTS "contacts_pkey";

        -- Change the type
        ALTER TABLE "public"."contacts" ALTER COLUMN "wa_id" TYPE TEXT USING wa_id::TEXT;

        -- Also change messages.chat_id to match (it references contacts.wa_id)
        ALTER TABLE "public"."messages" ALTER COLUMN "chat_id" TYPE TEXT USING chat_id::TEXT;

        -- Also change appointment_reminders.wa_id to match
        ALTER TABLE "public"."appointment_reminders" ALTER COLUMN "wa_id" TYPE TEXT USING wa_id::TEXT;

        -- Add back primary key on wa_id
        ALTER TABLE "public"."contacts" ADD CONSTRAINT "contacts_pkey" PRIMARY KEY ("wa_id");

        -- Recreate the foreign key constraint with the new type
        ALTER TABLE "public"."appointment_reminders"
        ADD CONSTRAINT "appointment_reminders_wa_id_fkey"
        FOREIGN KEY ("wa_id") REFERENCES "contacts"("wa_id") ON DELETE CASCADE;

        -- Recreate RLS policies
        CREATE POLICY "Enable select for admin users and agent users to their contacts on contacts"
        ON "public"."contacts" AS PERMISSIVE FOR SELECT TO authenticated
        USING (
            (SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin' OR
            ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'agent' AND auth.uid() = assigned_to)
        );

        CREATE POLICY "Enable update for admin users and agent users to their contacts on contacts"
        ON "public"."contacts" AS PERMISSIVE FOR UPDATE TO authenticated
        USING (
            (SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin' OR
            ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'agent' AND auth.uid() = assigned_to)
        )
        WITH CHECK (
            (SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin' OR
            ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'agent' AND auth.uid() = assigned_to)
        );

        CREATE POLICY "Enable insert for admin users only on contacts"
        ON "public"."contacts" AS PERMISSIVE FOR INSERT TO authenticated
        WITH CHECK ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin');

        CREATE POLICY "Enable delete for admin users only on contacts"
        ON "public"."contacts" AS PERMISSIVE FOR DELETE TO authenticated
        USING ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin');

        CREATE POLICY "Enable select for admin users and agent users to their contacts on messages"
        ON "public"."messages" AS PERMISSIVE FOR SELECT TO authenticated
        USING (
            (SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin' OR
            ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'agent' AND chat_id IN (SELECT wa_id FROM contacts WHERE auth.uid() = assigned_to))
        );

        CREATE POLICY "Enable update for admin users and agent users to their contacts on messages"
        ON "public"."messages" AS PERMISSIVE FOR UPDATE TO authenticated
        USING (
            (SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin' OR
            ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'agent' AND chat_id IN (SELECT wa_id FROM contacts WHERE auth.uid() = assigned_to))
        )
        WITH CHECK (
            (SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin' OR
            ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'agent' AND chat_id IN (SELECT wa_id FROM contacts WHERE auth.uid() = assigned_to))
        );

        CREATE POLICY "Enable insert for admin users and agent users to their contacts on messages"
        ON "public"."messages" AS PERMISSIVE FOR INSERT TO authenticated
        WITH CHECK (
            (SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin' OR
            ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'agent' AND chat_id IN (SELECT wa_id FROM contacts WHERE auth.uid() = assigned_to))
        );

        CREATE POLICY "Enable delete for admin users only on messages"
        ON "public"."messages" AS PERMISSIVE FOR DELETE TO authenticated
        USING ((SELECT auth.jwt() -> 'user_metadata' ->> 'custom_user_role') = 'admin');
    END IF;
END $$;

-- Add foreign key to conversations for contact_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'conversations_contact_id_fkey'
    ) THEN
        ALTER TABLE "public"."conversations"
        ADD CONSTRAINT "conversations_contact_id_fkey"
        FOREIGN KEY ("contact_id") REFERENCES "contacts"("wa_id") ON DELETE CASCADE;
    END IF;
END $$;

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_phone_numbers_tenant ON phone_numbers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_contacts_tenant_wa ON contacts(tenant_id, wa_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_tenant_last ON contacts(tenant_id, last_message_at DESC) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_profile_trgm ON contacts USING gin (profile_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_conversations_tenant_number_status ON conversations(tenant_id, phone_number_id, status);
CREATE INDEX IF NOT EXISTS idx_conversations_tenant_updated ON conversations(tenant_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_chat_time ON messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_templates_tenant ON message_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_bot_intents_tenant_active ON bot_intents(tenant_id, active);
CREATE INDEX IF NOT EXISTS idx_bot_intents_phrase_trgm ON bot_intents USING gin (phrase gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_bot_intents_tenant_key ON bot_intents(tenant_id, key, active);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Extract human-visible text from message JSONB
CREATE OR REPLACE FUNCTION public.get_msg_text(msg jsonb)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(
    msg->'text'->>'body',
    msg->'interactive'->'button_reply'->>'title',
    msg->'interactive'->'list_reply'->>'title',
    msg->>'body',
    ''
  );
$$;

-- Touch contact on message
CREATE OR REPLACE FUNCTION fn_touch_contact_on_message()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE contacts c
     SET last_message_at = new.created_at,
         last_message_received_at = CASE WHEN new.is_received THEN new.created_at ELSE c.last_message_received_at END,
         unread_count = CASE WHEN new.is_received THEN COALESCE(c.unread_count,0) + 1 ELSE c.unread_count END
   WHERE c.wa_id::text = new.chat_id::text
     AND COALESCE(c.voided, false) = false;
  RETURN new;
END $$;

-- Touch session window
CREATE OR REPLACE FUNCTION fn_touch_session_window()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE c_rec record;
BEGIN
  IF new.is_received AND EXISTS (SELECT 1 FROM contacts WHERE wa_id::text = new.chat_id::text AND tenant_id IS NOT NULL) THEN
    SELECT * INTO c_rec FROM contacts WHERE wa_id::text = new.chat_id::text AND COALESCE(voided, false) = false;
    IF FOUND THEN
      INSERT INTO conversations (
        tenant_id, phone_number_id, contact_id,
        session_expires_at, last_user_msg_at, updated_at
      )
      VALUES (
        c_rec.tenant_id, c_rec.phone_number_id, c_rec.wa_id::text,
        new.created_at + interval '24 hours', new.created_at, now()
      )
      ON CONFLICT (tenant_id, contact_id, phone_number_id) DO UPDATE
        SET session_expires_at = excluded.session_expires_at,
            last_user_msg_at   = excluded.last_user_msg_at,
            updated_at         = now();
    END IF;
  END IF;
  RETURN new;
END $$;

-- Pick intent on inbound
CREATE OR REPLACE FUNCTION fn_pick_intent_on_inbound()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE c_rec record; msg text; chosen_key text;
BEGIN
  IF NOT new.is_received THEN RETURN new; END IF;

  IF NOT EXISTS (SELECT 1 FROM contacts WHERE wa_id::text = new.chat_id::text AND tenant_id IS NOT NULL) THEN
    RETURN new;
  END IF;

  SELECT * INTO c_rec FROM contacts WHERE wa_id::text = new.chat_id::text AND COALESCE(voided, false) = false;
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
     AND contact_id::text = c_rec.wa_id::text
     AND voided = false;

  RETURN new;
END $$;

-- Echo handover (minimal & safe)
CREATE OR REPLACE FUNCTION fn_echo_handover_min_safe()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  ts timestamptz := COALESCE(new.created_at, now());
  mute_seconds int;
  c_rec record;
  p_rec phone_numbers;
  t_rec tenants;
BEGIN
  -- outbound only
  IF new.is_received THEN RETURN new; END IF;

  -- detect echo flag in payload
  IF NOT (COALESCE((new.message->>'origin')='agent_app',false)
          OR COALESCE((new.message->>'echo')::boolean,false)) THEN
    RETURN new;
  END IF;

  -- Only process for multi-tenant contacts
  IF NOT EXISTS (SELECT 1 FROM contacts WHERE wa_id::text = new.chat_id::text AND tenant_id IS NOT NULL) THEN
    RETURN new;
  END IF;

  -- resolve settings via contact -> phone_number -> tenant
  SELECT * INTO c_rec FROM contacts WHERE wa_id::text = new.chat_id::text AND COALESCE(voided, false) = false;
  IF NOT FOUND THEN RETURN new; END IF;

  SELECT * INTO p_rec FROM phone_numbers WHERE id = c_rec.phone_number_id AND voided = false;
  SELECT * INTO t_rec FROM tenants WHERE id = c_rec.tenant_id AND voided = false;

  IF COALESCE(p_rec.auto_handover_on_echo, true) IS FALSE THEN
    RETURN new;
  END IF;

  SELECT COALESCE(p_rec.echo_handover_mute_seconds, t_rec.echo_handover_mute_seconds, 86400)
    INTO mute_seconds;
  IF mute_seconds IS NULL THEN RETURN new; END IF;

  -- upsert conversation, set human + extend mute
  INSERT INTO conversations (tenant_id, phone_number_id, contact_id, status, mute_bot_until, last_agent_msg_at, updated_at)
  VALUES (c_rec.tenant_id, c_rec.phone_number_id, c_rec.wa_id::text, 'human', ts + (mute_seconds || ' seconds')::interval, ts, now())
  ON CONFLICT (tenant_id, contact_id, phone_number_id) DO UPDATE
    SET status          = 'human',
        mute_bot_until  = GREATEST(conversations.mute_bot_until, excluded.mute_bot_until),
        last_agent_msg_at = ts,
        updated_at      = now();

  -- optional UI hint
  UPDATE contacts
     SET in_chat = true
   WHERE wa_id::text = c_rec.wa_id::text AND COALESCE(voided, false) = false;

  RETURN new;
END $$;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Multi-tenant message triggers (ordered by execution sequence)
DROP TRIGGER IF EXISTS trg_msg_10_touch_contact ON messages;
CREATE TRIGGER trg_msg_10_touch_contact
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_touch_contact_on_message();

DROP TRIGGER IF EXISTS trg_msg_20_touch_session ON messages;
CREATE TRIGGER trg_msg_20_touch_session
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_touch_session_window();

DROP TRIGGER IF EXISTS trg_msg_30_pick_intent ON messages;
CREATE TRIGGER trg_msg_30_pick_intent
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_pick_intent_on_inbound();

DROP TRIGGER IF EXISTS trg_msg_40_echo_handover ON messages;
CREATE TRIGGER trg_msg_40_echo_handover
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION fn_echo_handover_min_safe();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."phone_numbers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."message_template" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."bot_intents" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."handover_events" ENABLE ROW LEVEL SECURITY;

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

-- Phone numbers
DROP POLICY IF EXISTS tn_select_phone_numbers ON phone_numbers;
CREATE POLICY tn_select_phone_numbers ON phone_numbers
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);
DROP POLICY IF EXISTS tn_modify_phone_numbers ON phone_numbers;
CREATE POLICY tn_modify_phone_numbers ON phone_numbers
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

-- Templates (existing message_template table with multi-tenancy)
DROP POLICY IF EXISTS tn_select_templates ON message_template;
CREATE POLICY tn_select_templates ON message_template
  FOR SELECT USING (tenant_id IS NULL OR (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false));
DROP POLICY IF EXISTS tn_modify_templates ON message_template;
CREATE POLICY tn_modify_templates ON message_template
  FOR ALL USING (tenant_id IS NULL OR tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id IS NULL OR tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Bot intents
DROP POLICY IF EXISTS tn_select_bot_intents ON bot_intents;
CREATE POLICY tn_select_bot_intents ON bot_intents
  FOR SELECT USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','') AND voided = false);
DROP POLICY IF EXISTS tn_modify_bot_intents ON bot_intents;
CREATE POLICY tn_modify_bot_intents ON bot_intents
  FOR ALL USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Handover events
DROP POLICY IF EXISTS tn_select_handover_events ON handover_events;
CREATE POLICY tn_select_handover_events ON handover_events
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM conversations cv
              JOIN contacts c ON c.wa_id::text = cv.contact_id::text
            WHERE cv.id = handover_events.conversation_id
              AND cv.tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','')
              AND cv.voided = false)
  );
DROP POLICY IF EXISTS tn_modify_handover_events ON handover_events;
CREATE POLICY tn_modify_handover_events ON handover_events
  FOR ALL USING (
    EXISTS (SELECT 1 FROM conversations cv
              JOIN contacts c ON c.wa_id::text = cv.contact_id::text
            WHERE cv.id = handover_events.conversation_id
              AND cv.tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM conversations cv
              JOIN contacts c ON c.wa_id::text = cv.contact_id::text
            WHERE cv.id = handover_events.conversation_id
              AND cv.tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  );

-- ============================================================================
-- PUBLICATIONS (Realtime) - Add conversations
-- ============================================================================

DO $$
BEGIN
  -- Add conversations to existing publication if it exists
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN others THEN NULL;
END $$;
