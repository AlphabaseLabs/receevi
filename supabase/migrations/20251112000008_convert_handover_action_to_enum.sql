-- Migration: Convert handover_events.action from TEXT to ENUM
-- Date: 2025-11-12
-- Reasoning: Type safety and consistency with message_sender_type

-- ============================================================================
-- 1. Create ENUM for handover action types
-- ============================================================================

CREATE TYPE public.handover_action_type AS ENUM (
  'request',      -- Manual handover request from agent
  'grant',        -- Handover granted (auto or manual)
  'release',      -- Conversation released back to bot
  'timeout',      -- Handover expired due to timeout
  'auto_close'    -- Auto-closed by system
);

-- ============================================================================
-- 2. Convert action column from TEXT to ENUM
-- ============================================================================

-- Step 1: Add new column with ENUM type
ALTER TABLE public.handover_events
ADD COLUMN action_new public.handover_action_type;

-- Step 2: Copy data from old column to new column
UPDATE public.handover_events
SET action_new = action::public.handover_action_type;

-- Step 3: Drop old column
ALTER TABLE public.handover_events
DROP COLUMN action;

-- Step 4: Rename new column to action
ALTER TABLE public.handover_events
RENAME COLUMN action_new TO action;

-- Step 5: Make it NOT NULL
ALTER TABLE public.handover_events
ALTER COLUMN action SET NOT NULL;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TYPE public.handover_action_type IS
'Types of handover actions: request (manual), grant (auto/manual), release (back to bot), timeout (expired), auto_close (system closed)';

COMMENT ON COLUMN public.handover_events.action IS
'Type of handover action that occurred';
