-- Migration: Remove phone_number_id from contacts/conversations and make wa_phone_number_id globally unique
-- Date: 2025-11-12
-- Reasoning: Each tenant has only ONE WhatsApp business number, no need for multi-number support

-- ============================================================================
-- 1. Drop foreign key constraints
-- ============================================================================

ALTER TABLE public.contacts
DROP CONSTRAINT IF EXISTS contacts_phone_number_id_fkey;

ALTER TABLE public.conversations
DROP CONSTRAINT IF EXISTS conversations_phone_number_id_fkey;

-- ============================================================================
-- 2. Drop indexes and constraints that include phone_number_id
-- ============================================================================

-- Drop conversations unique constraint that includes phone_number_id
ALTER TABLE public.conversations
DROP CONSTRAINT IF EXISTS conversations_tenant_id_contact_wa_id_phone_number_id_key;

-- Drop index that includes phone_number_id
DROP INDEX IF EXISTS public.idx_conversations_tenant_number_status;

-- ============================================================================
-- 3. Remove phone_number_id columns
-- ============================================================================

ALTER TABLE public.contacts
DROP COLUMN IF EXISTS phone_number_id;

ALTER TABLE public.conversations
DROP COLUMN IF EXISTS phone_number_id;

-- ============================================================================
-- 4. Update conversations unique constraint (without phone_number_id)
-- ============================================================================

-- Now unique per tenant + contact only
ALTER TABLE public.conversations
ADD CONSTRAINT conversations_tenant_id_contact_wa_id_key
UNIQUE (tenant_id, contact_wa_id);

-- Add index for performance (without phone_number_id)
CREATE INDEX IF NOT EXISTS idx_conversations_tenant_status
ON public.conversations(tenant_id, status)
WHERE voided = false;

-- ============================================================================
-- 5. Make wa_phone_number globally unique in phone_numbers
-- ============================================================================

-- Drop old constraint (tenant_id, wa_phone_number)
ALTER TABLE public.phone_numbers
DROP CONSTRAINT IF EXISTS phone_numbers_tenant_id_wa_phone_number_key;

-- Add new global unique constraint (wa_phone_number only)
ALTER TABLE public.phone_numbers
ADD CONSTRAINT phone_numbers_wa_phone_number_key
UNIQUE (wa_phone_number);

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON CONSTRAINT phone_numbers_wa_phone_number_key ON public.phone_numbers IS
'WhatsApp phone number must be globally unique - one number can only belong to one tenant';

COMMENT ON CONSTRAINT conversations_tenant_id_contact_wa_id_key ON public.conversations IS
'One conversation per contact per tenant (removed phone_number_id - tenants have only one business number)';

COMMENT ON TABLE public.phone_numbers IS
'WhatsApp Business phone numbers owned by tenants. Each tenant has ONE business number.';
