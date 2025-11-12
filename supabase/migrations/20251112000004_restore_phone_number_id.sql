-- Migration: Restore phone_number_id to contacts and conversations
-- Date: 2025-11-12
-- Reasoning: Keep phone_number_id for context tracking, but maintain global unique wa_phone_number

-- ============================================================================
-- 1. Add phone_number_id back to contacts
-- ============================================================================

ALTER TABLE public.contacts
ADD COLUMN IF NOT EXISTS phone_number_id UUID REFERENCES public.phone_numbers(id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_contacts_phone_number
ON public.contacts(phone_number_id);

-- ============================================================================
-- 2. Add phone_number_id back to conversations
-- ============================================================================

ALTER TABLE public.conversations
ADD COLUMN IF NOT EXISTS phone_number_id UUID REFERENCES public.phone_numbers(id);

-- ============================================================================
-- 3. Update conversations unique constraint (restore phone_number_id)
-- ============================================================================

-- Drop the constraint without phone_number_id
ALTER TABLE public.conversations
DROP CONSTRAINT IF EXISTS conversations_tenant_id_contact_wa_id_key;

-- Add back constraint with phone_number_id
ALTER TABLE public.conversations
ADD CONSTRAINT conversations_tenant_id_contact_wa_id_phone_number_id_key
UNIQUE (tenant_id, contact_wa_id, phone_number_id);

-- Add back index with phone_number_id
CREATE INDEX IF NOT EXISTS idx_conversations_tenant_number_status
ON public.conversations(tenant_id, phone_number_id, status)
WHERE voided = false;

-- Drop the index without phone_number_id
DROP INDEX IF EXISTS public.idx_conversations_tenant_status;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON COLUMN public.contacts.phone_number_id IS
'References the WhatsApp Business phone number this contact is associated with. Optional for flexibility.';

COMMENT ON COLUMN public.conversations.phone_number_id IS
'References the WhatsApp Business phone number for this conversation. Tracks which business line the conversation is on.';

COMMENT ON CONSTRAINT conversations_tenant_id_contact_wa_id_phone_number_id_key ON public.conversations IS
'One conversation per contact per phone number per tenant. Allows multi-number support if needed.';
