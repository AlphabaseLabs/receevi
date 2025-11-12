-- Migration: Remove tenant_contacts table and use profiles for tenant association
-- Date: 2025-11-12

-- ============================================================================
-- 1. Drop tenant_contacts table and dependencies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_tenant_contacts ON public.tenant_contacts;
DROP POLICY IF EXISTS tn_modify_tenant_contacts ON public.tenant_contacts;

DROP TABLE IF EXISTS public.tenant_contacts CASCADE;

DROP TYPE IF EXISTS public.tenant_contact_role CASCADE;

-- ============================================================================
-- 2. Add tenant_id to profiles table
-- ============================================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);

-- ============================================================================
-- 3. Update RLS policies to use profiles lookup instead of JWT custom claims
-- ============================================================================

-- Helper function to get current user's tenant_id from profiles
CREATE OR REPLACE FUNCTION public.get_user_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT tenant_id FROM public.profiles WHERE id = auth.uid();
$$;

-- Grant execute to all authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_tenant_id() TO authenticated;

-- ============================================================================
-- Update messages policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_messages ON public.messages;
DROP POLICY IF EXISTS tn_modify_messages ON public.messages;

CREATE POLICY tn_select_messages ON public.messages
  FOR SELECT
  USING (tenant_id = public.get_user_tenant_id());

CREATE POLICY tn_modify_messages ON public.messages
  FOR ALL
  USING (tenant_id = public.get_user_tenant_id())
  WITH CHECK (tenant_id = public.get_user_tenant_id());

-- ============================================================================
-- Update contacts policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_contacts ON public.contacts;
DROP POLICY IF EXISTS tn_modify_contacts ON public.contacts;

CREATE POLICY tn_select_contacts ON public.contacts
  FOR SELECT
  USING (tenant_id = public.get_user_tenant_id() AND voided = false);

CREATE POLICY tn_modify_contacts ON public.contacts
  FOR ALL
  USING (tenant_id = public.get_user_tenant_id())
  WITH CHECK (tenant_id = public.get_user_tenant_id());

-- ============================================================================
-- Update conversations policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_conversations ON public.conversations;
DROP POLICY IF EXISTS tn_modify_conversations ON public.conversations;

CREATE POLICY tn_select_conversations ON public.conversations
  FOR SELECT
  USING (tenant_id = public.get_user_tenant_id() AND voided = false);

CREATE POLICY tn_modify_conversations ON public.conversations
  FOR ALL
  USING (tenant_id = public.get_user_tenant_id())
  WITH CHECK (tenant_id = public.get_user_tenant_id());

-- ============================================================================
-- Update phone_numbers policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_phone_numbers ON public.phone_numbers;
DROP POLICY IF EXISTS tn_modify_phone_numbers ON public.phone_numbers;

CREATE POLICY tn_select_phone_numbers ON public.phone_numbers
  FOR SELECT
  USING (tenant_id = public.get_user_tenant_id() AND voided = false);

CREATE POLICY tn_modify_phone_numbers ON public.phone_numbers
  FOR ALL
  USING (tenant_id = public.get_user_tenant_id())
  WITH CHECK (tenant_id = public.get_user_tenant_id());

-- ============================================================================
-- Update appointment_reminders policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_appointment_reminders ON public.appointment_reminders;
DROP POLICY IF EXISTS tn_modify_appointment_reminders ON public.appointment_reminders;

CREATE POLICY tn_select_appointment_reminders ON public.appointment_reminders
  FOR SELECT
  USING (tenant_id = public.get_user_tenant_id());

CREATE POLICY tn_modify_appointment_reminders ON public.appointment_reminders
  FOR ALL
  USING (tenant_id = public.get_user_tenant_id())
  WITH CHECK (tenant_id = public.get_user_tenant_id());

-- ============================================================================
-- Update bot_intents policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_bot_intents ON public.bot_intents;
DROP POLICY IF EXISTS tn_modify_bot_intents ON public.bot_intents;

CREATE POLICY tn_select_bot_intents ON public.bot_intents
  FOR SELECT
  USING (tenant_id = public.get_user_tenant_id() AND voided = false);

CREATE POLICY tn_modify_bot_intents ON public.bot_intents
  FOR ALL
  USING (tenant_id = public.get_user_tenant_id())
  WITH CHECK (tenant_id = public.get_user_tenant_id());

-- ============================================================================
-- Update tenant_integrations policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_integrations ON public.tenant_integrations;
DROP POLICY IF EXISTS tn_modify_integrations ON public.tenant_integrations;

CREATE POLICY tn_select_integrations ON public.tenant_integrations
  FOR SELECT
  USING (tenant_id = public.get_user_tenant_id() AND voided = false);

CREATE POLICY tn_modify_integrations ON public.tenant_integrations
  FOR ALL
  USING (tenant_id = public.get_user_tenant_id())
  WITH CHECK (tenant_id = public.get_user_tenant_id());

-- ============================================================================
-- Update tenants policies
-- ============================================================================

DROP POLICY IF EXISTS tn_select_tenants ON public.tenants;
DROP POLICY IF EXISTS tn_modify_tenants ON public.tenants;

CREATE POLICY tn_select_tenants ON public.tenants
  FOR SELECT
  USING (id = public.get_user_tenant_id() AND voided = false);

CREATE POLICY tn_modify_tenants ON public.tenants
  FOR ALL
  USING (id = public.get_user_tenant_id())
  WITH CHECK (id = public.get_user_tenant_id());

-- ============================================================================
-- Comment on changes
-- ============================================================================

COMMENT ON COLUMN public.profiles.tenant_id IS 'Links user to their tenant organization for multi-tenant access control';
COMMENT ON FUNCTION public.get_user_tenant_id() IS 'Helper function to get current authenticated users tenant_id from profiles table';
