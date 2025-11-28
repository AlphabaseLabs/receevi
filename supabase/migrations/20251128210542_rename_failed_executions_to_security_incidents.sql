-- ============================================================================
-- Rename failed_executions to security_incidents
-- Better reflects the purpose: tracking security threats and policy violations
-- ============================================================================

-- Rename the table
ALTER TABLE "public"."failed_executions" RENAME TO "security_incidents";

-- Update table comment
COMMENT ON TABLE "public"."security_incidents" IS 'Tracks security incidents, policy violations, prompt injections, and other threats detected during message processing';

-- Rename indexes (with safe error handling)
DO $$
BEGIN
  -- Rename each index, skip if doesn't exist
  BEGIN
    ALTER INDEX "idx_failed_executions_tenant" RENAME TO "idx_security_incidents_tenant";
  EXCEPTION WHEN undefined_table THEN NULL;
  END;

  BEGIN
    ALTER INDEX "idx_failed_executions_tenant_created" RENAME TO "idx_security_incidents_tenant_created";
  EXCEPTION WHEN undefined_table THEN NULL;
  END;

  BEGIN
    ALTER INDEX "idx_failed_executions_status" RENAME TO "idx_security_incidents_status";
  EXCEPTION WHEN undefined_table THEN NULL;
  END;

  BEGIN
    ALTER INDEX "idx_failed_executions_category" RENAME TO "idx_security_incidents_category";
  EXCEPTION WHEN undefined_table THEN NULL;
  END;

  BEGIN
    ALTER INDEX "idx_failed_executions_step" RENAME TO "idx_security_incidents_step";
  EXCEPTION WHEN undefined_table THEN NULL;
  END;

  BEGIN
    ALTER INDEX "idx_failed_executions_phone_number" RENAME TO "idx_security_incidents_phone_number";
  EXCEPTION WHEN undefined_table THEN NULL;
  END;

  BEGIN
    ALTER INDEX "idx_failed_executions_wam_id" RENAME TO "idx_security_incidents_wam_id";
  EXCEPTION WHEN undefined_table THEN NULL;
  END;
END $$;

-- Drop old policies
DROP POLICY IF EXISTS "tn_select_failed_executions" ON "public"."security_incidents";
DROP POLICY IF EXISTS "tn_modify_failed_executions" ON "public"."security_incidents";

-- Create new policies with updated names
CREATE POLICY "tn_select_security_incidents" ON "public"."security_incidents"
  FOR SELECT
  USING (
    tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','')
    AND voided = false
  );

CREATE POLICY "tn_modify_security_incidents" ON "public"."security_incidents"
  FOR ALL
  USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));
