-- ============================================================================
-- Failed Executions Table for Backoffice
-- Stores executions that failed due to prompt injection, misuse, or other violations
-- ============================================================================

-- Create enum for common failure categories (optional field)
DO $$ BEGIN
  CREATE TYPE public.execution_failure_category AS ENUM (
    'prompt_injection',
    'misuse_query',
    'content_policy_violation',
    'rate_limit_exceeded',
    'safety_filter',
    'parsing_error',
    'service_unavailable',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create enum for execution status
DO $$ BEGIN
  CREATE TYPE public.execution_status AS ENUM (
    'rejected',
    'human_review',
    'quarantine',
    'accepted_with_warnings',
    'clean'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create enum for execution pipeline step
DO $$ BEGIN
  CREATE TYPE public.execution_step AS ENUM (
    'input_validation',
    'sanitization',
    'pre_processing',
    'intent_detection',
    'policy_check',
    'content_generation',
    'post_processing',
    'final_guardrail',
    'output_validation',
    'delivery'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Drop table if exists (clean slate for new schema)
DROP TABLE IF EXISTS "public"."failed_executions" CASCADE;

-- Create failed_executions table
CREATE TABLE "public"."failed_executions" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "tenant_id" UUID NOT NULL REFERENCES "public"."tenants"("id") ON DELETE CASCADE,
  "phone_number_id" UUID REFERENCES "public"."phone_numbers"("id") ON DELETE SET NULL,
  "contact_wa_id" TEXT,
  "wam_id" TEXT,
  "status" execution_status NOT NULL DEFAULT 'human_review',
  "step" execution_step,
  "failure_reason" TEXT NOT NULL,
  "failure_category" execution_failure_category,
  "failure_details" JSONB,
  "message" TEXT NOT NULL,
  "wa_raw_message" JSONB,
  "bot_response" TEXT,
  "metadata" JSONB DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  "reviewed_at" TIMESTAMP WITH TIME ZONE,
  "reviewed_by" UUID REFERENCES "auth"."users"("id") ON DELETE SET NULL,
  "voided" BOOLEAN DEFAULT false NOT NULL,
  "voided_at" TIMESTAMP WITH TIME ZONE
);

-- Add comment to table
COMMENT ON TABLE "public"."failed_executions" IS 'Stores failed bot executions due to policy violations, prompt injections, misuse, etc.';

-- Add comments to columns
COMMENT ON COLUMN "public"."failed_executions"."phone_number_id" IS 'Reference to phone_numbers table - used with tenant_id to link back to conversations';
COMMENT ON COLUMN "public"."failed_executions"."wam_id" IS 'WhatsApp message ID - stored as text for async operations, can join with messages.wam_id if needed';
COMMENT ON COLUMN "public"."failed_executions"."status" IS 'Current status of the execution: rejected, human_review, quarantine, accepted_with_warnings, clean';
COMMENT ON COLUMN "public"."failed_executions"."step" IS 'Pipeline step where execution was stopped: input_validation, sanitization, pre_processing, intent_detection, policy_check, content_generation, post_processing, final_guardrail, output_validation, delivery';
COMMENT ON COLUMN "public"."failed_executions"."failure_reason" IS 'Freeform text description of why the execution failed';
COMMENT ON COLUMN "public"."failed_executions"."failure_category" IS 'Optional categorization of the failure reason using predefined enum values';
COMMENT ON COLUMN "public"."failed_executions"."failure_details" IS 'Additional context about the failure (e.g., matched patterns, severity, scores)';
COMMENT ON COLUMN "public"."failed_executions"."message" IS 'The original message text from the user that triggered the failure';
COMMENT ON COLUMN "public"."failed_executions"."wa_raw_message" IS 'Raw WhatsApp message payload as received from webhook';
COMMENT ON COLUMN "public"."failed_executions"."bot_response" IS 'The response sent to user if any (e.g., error message)';
COMMENT ON COLUMN "public"."failed_executions"."metadata" IS 'Additional metadata like model version, timestamp, detection scores, etc.';
COMMENT ON COLUMN "public"."failed_executions"."reviewed_at" IS 'Timestamp when human review was completed';
COMMENT ON COLUMN "public"."failed_executions"."reviewed_by" IS 'User ID of who reviewed this execution';

-- Create indexes
CREATE INDEX "idx_failed_executions_tenant"
  ON "public"."failed_executions"("tenant_id")
  WHERE voided = false;

CREATE INDEX "idx_failed_executions_tenant_created"
  ON "public"."failed_executions"("tenant_id", "created_at" DESC)
  WHERE voided = false;

CREATE INDEX "idx_failed_executions_status"
  ON "public"."failed_executions"("tenant_id", "status")
  WHERE voided = false;

CREATE INDEX "idx_failed_executions_category"
  ON "public"."failed_executions"("tenant_id", "failure_category")
  WHERE voided = false AND failure_category IS NOT NULL;

CREATE INDEX "idx_failed_executions_phone_number"
  ON "public"."failed_executions"("tenant_id", "phone_number_id")
  WHERE voided = false AND phone_number_id IS NOT NULL;

CREATE INDEX "idx_failed_executions_wam_id"
  ON "public"."failed_executions"("wam_id")
  WHERE voided = false AND wam_id IS NOT NULL;

-- Enable Row Level Security
ALTER TABLE "public"."failed_executions" ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Select policy: users can only see failed executions from their tenant
DROP POLICY IF EXISTS "tn_select_failed_executions" ON "public"."failed_executions";
CREATE POLICY "tn_select_failed_executions" ON "public"."failed_executions"
  FOR SELECT
  USING (
    tenant_id::text = COALESCE(auth.jwt()->>'tenant_id','')
    AND voided = false
  );

-- Modify policy: users can only modify failed executions from their tenant
DROP POLICY IF EXISTS "tn_modify_failed_executions" ON "public"."failed_executions";
CREATE POLICY "tn_modify_failed_executions" ON "public"."failed_executions"
  FOR ALL
  USING (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''))
  WITH CHECK (tenant_id::text = COALESCE(auth.jwt()->>'tenant_id',''));

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "public"."failed_executions" TO "authenticated";
GRANT ALL ON TABLE "public"."failed_executions" TO "service_role";

-- Add to realtime publication if needed (optional for backoffice)
-- ALTER PUBLICATION supabase_realtime ADD TABLE "public"."failed_executions";
