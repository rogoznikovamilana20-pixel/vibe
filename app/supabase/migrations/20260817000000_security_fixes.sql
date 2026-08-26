-- ============================================================
-- SECURITY FIXES — Phase 4/5/6 certification
-- Project: rgdwfoicidnamejluxfx
-- Date: 2026-08-17
-- ============================================================

-- 1. P0: Revoke exec_sql from anon (SECURITY DEFINER vulnerability)
--    Confirmed: anon could UPDATE/DELETE any table via exec_sql
REVOKE EXECUTE ON FUNCTION public.exec_sql(text) FROM anon;

-- 2. P1: Fix message_edits RLS — only message author can create edit records
--    Was: edits_insert CHECK(true) — any user could insert edits for any message
DROP POLICY IF EXISTS edits_insert ON public.message_edits;
CREATE POLICY edits_insert ON public.message_edits FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM messages m
      WHERE m.id = message_id AND m.sender_id = auth.uid()
    )
  );

-- 3. P1: Drop duplicate indexes
--    chats_members_gin already exists, chats_members_idx is redundant
--    messages_chat_idx already exists, messages_chat_id_idx is redundant
DROP INDEX IF EXISTS public.chats_members_idx;
DROP INDEX IF EXISTS public.messages_chat_id_idx;
