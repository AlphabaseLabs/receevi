-- Migration: Add sender_type to messages table for tracking message origin
-- Date: 2025-11-12
-- Reasoning: Need to distinguish between customer, bot, agent, and WhatsApp coexistence messages

-- ============================================================================
-- 1. Create ENUM for message sender types
-- ============================================================================

CREATE TYPE public.message_sender_type AS ENUM (
  'customer',      -- Message from customer (inbound via WhatsApp)
  'bot',           -- Automated bot response
  'agent',         -- Message sent by agent via dashboard
  'coexistence'    -- Message sent by business user via WhatsApp mobile (coexistence)
);

-- ============================================================================
-- 2. Add sender_type column to messages table
-- ============================================================================

ALTER TABLE public.messages
ADD COLUMN sender_type public.message_sender_type NOT NULL DEFAULT 'customer';

-- Create index for filtering by sender type
CREATE INDEX IF NOT EXISTS idx_messages_sender_type
ON public.messages(tenant_id, sender_type, created_at DESC);

-- ============================================================================
-- 3. Update existing data based on is_received
-- ============================================================================

-- Set sender_type based on is_received:
-- - is_received = true → 'customer' (already default)
-- - is_received = false → 'bot' (assumption: existing outbound messages are bot responses)
UPDATE public.messages
SET sender_type = 'bot'
WHERE is_received = false;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TYPE public.message_sender_type IS
'Identifies who sent the message: customer (inbound), bot (automated), agent (dashboard), or coexistence (WhatsApp mobile)';

COMMENT ON COLUMN public.messages.sender_type IS
'Identifies the sender type: customer (inbound from WhatsApp), bot (automated response), agent (sent via dashboard), coexistence (sent via WhatsApp mobile by business user)';
