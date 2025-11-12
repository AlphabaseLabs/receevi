-- Migration: Fix RLS policies to use get_user_tenant_id() consistently
-- Date: 2025-11-12

-- ============================================================================
-- 1. Fix tenants table - Remove duplicate old policies
-- ============================================================================

DROP POLICY IF EXISTS tenants_select ON public.tenants;
DROP POLICY IF EXISTS tenants_update ON public.tenants;

-- Keep only the new policies (tn_select_tenants, tn_modify_tenants)

-- ============================================================================
-- 2. Fix message_template - Update to use get_user_tenant_id()
-- ============================================================================

DROP POLICY IF EXISTS tn_modify_templates ON public.message_template;
DROP POLICY IF EXISTS tn_select_templates ON public.message_template;
DROP POLICY IF EXISTS "Enable all for authenticated users only on message_templates" ON public.message_template;

CREATE POLICY tn_select_templates ON public.message_template
  FOR SELECT
  USING (
    (tenant_id IS NULL) OR
    (tenant_id = get_user_tenant_id() AND voided = false)
  );

CREATE POLICY tn_modify_templates ON public.message_template
  FOR ALL
  USING (
    (tenant_id IS NULL) OR
    (tenant_id = get_user_tenant_id())
  )
  WITH CHECK (
    (tenant_id IS NULL) OR
    (tenant_id = get_user_tenant_id())
  );

-- ============================================================================
-- 3. Fix handover_events - Update to use get_user_tenant_id()
-- ============================================================================

DROP POLICY IF EXISTS tn_select_handover_events ON public.handover_events;
DROP POLICY IF EXISTS tn_modify_handover_events ON public.handover_events;

CREATE POLICY tn_select_handover_events ON public.handover_events
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations cv
      WHERE cv.id = handover_events.conversation_id
        AND cv.tenant_id = get_user_tenant_id()
        AND cv.voided = false
    )
  );

CREATE POLICY tn_modify_handover_events ON public.handover_events
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations cv
      WHERE cv.id = handover_events.conversation_id
        AND cv.tenant_id = get_user_tenant_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.conversations cv
      WHERE cv.id = handover_events.conversation_id
        AND cv.tenant_id = get_user_tenant_id()
    )
  );

-- ============================================================================
-- 4. Add missing tenant_id to broadcast tables
-- ============================================================================

-- Add tenant_id to broadcast
ALTER TABLE public.broadcast
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_broadcast_tenant_id ON public.broadcast(tenant_id);

-- Add tenant_id to broadcast_batch
ALTER TABLE public.broadcast_batch
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_broadcast_batch_tenant_id ON public.broadcast_batch(tenant_id);

-- Add tenant_id to broadcast_contact
ALTER TABLE public.broadcast_contact
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_broadcast_contact_tenant_id ON public.broadcast_contact(tenant_id);

-- Update broadcast policies
DROP POLICY IF EXISTS "Enable all for admin users only on broadcast" ON public.broadcast;

CREATE POLICY tn_select_broadcast ON public.broadcast
  FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY tn_modify_broadcast ON public.broadcast
  FOR ALL
  USING (tenant_id = get_user_tenant_id())
  WITH CHECK (tenant_id = get_user_tenant_id());

-- Update broadcast_batch policies
DROP POLICY IF EXISTS "Enable all for admin users only on broadcast_batch" ON public.broadcast_batch;

CREATE POLICY tn_select_broadcast_batch ON public.broadcast_batch
  FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY tn_modify_broadcast_batch ON public.broadcast_batch
  FOR ALL
  USING (tenant_id = get_user_tenant_id())
  WITH CHECK (tenant_id = get_user_tenant_id());

-- Update broadcast_contact policies
DROP POLICY IF EXISTS "Enable all for admin users only on broadcast_contact" ON public.broadcast_contact;

CREATE POLICY tn_select_broadcast_contact ON public.broadcast_contact
  FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY tn_modify_broadcast_contact ON public.broadcast_contact
  FOR ALL
  USING (tenant_id = get_user_tenant_id())
  WITH CHECK (tenant_id = get_user_tenant_id());

-- ============================================================================
-- 5. Fix contact_tag - Add proper tenant isolation
-- ============================================================================

-- Check if contact_tag has tenant_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'contact_tag'
    AND column_name = 'tenant_id'
  ) THEN
    -- If no tenant_id, add it
    ALTER TABLE public.contact_tag
    ADD COLUMN tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

    CREATE INDEX idx_contact_tag_tenant_id ON public.contact_tag(tenant_id);
  END IF;
END $$;

DROP POLICY IF EXISTS "Enable all for authenticated users only on contact_tag" ON public.contact_tag;

CREATE POLICY tn_select_contact_tag ON public.contact_tag
  FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY tn_modify_contact_tag ON public.contact_tag
  FOR ALL
  USING (tenant_id = get_user_tenant_id())
  WITH CHECK (tenant_id = get_user_tenant_id());

-- ============================================================================
-- 6. Add policies for webhook table (admin only or service role)
-- ============================================================================

-- Webhooks are system-level, so only service role should access
CREATE POLICY webhook_service_role_all ON public.webhook
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 7. Add policies for role_permissions table (read-only for authenticated)
-- ============================================================================

-- Role permissions are shared config, read-only for all authenticated users
CREATE POLICY role_permissions_select ON public.role_permissions
  FOR SELECT
  TO authenticated
  USING (true);

-- Only service role can modify
CREATE POLICY role_permissions_modify ON public.role_permissions
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 8. Update profiles policy to allow users to read their own profile
-- ============================================================================

DROP POLICY IF EXISTS "Enable all for admin users only on profiles" ON public.profiles;

-- Users can read their own profile
CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT
  USING (id = auth.uid());

-- Users can update their own profile
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Service role has full access
CREATE POLICY profiles_service_role_all ON public.profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON POLICY tn_select_templates ON public.message_template IS 'Allow access to global templates (tenant_id IS NULL) or tenant-specific templates';
COMMENT ON POLICY tn_select_handover_events ON public.handover_events IS 'Access handover events through conversation tenant_id check';
COMMENT ON POLICY webhook_service_role_all ON public.webhook IS 'Webhooks are system-level, accessible only by service role';
COMMENT ON POLICY role_permissions_select ON public.role_permissions IS 'Role permissions are shared config, readable by all authenticated users';
