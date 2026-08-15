-- =============================================================
-- VIBE DATABASE CLEANUP + GRANT/REVOKE FIX + NEW TABLES
-- Project: rgdwfoicidnamejluxfx
-- Date: 2026-08-15
-- Status: APPLIED
-- =============================================================

-- =============================================================
-- PART 1: CLEANUP — удаление всех тестовых данных
-- =============================================================

DELETE FROM public.messages;
DELETE FROM public.stories;
DELETE FROM public.chats;
DELETE FROM public.profiles;

-- =============================================================
-- PART 2: NEW TABLES (created 2026-08-15)
-- =============================================================

-- read_states: кто сколько прочитал в чате
CREATE TABLE IF NOT EXISTS public.read_states (
  chat_id uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (chat_id, user_id)
);

-- message_reactions: реакции на сообщения
CREATE TABLE IF NOT EXISTS public.message_reactions (
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id, emoji)
);

-- chat_pins: закреплённые чаты
CREATE TABLE IF NOT EXISTS public.chat_pins (
  chat_id uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pinned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (chat_id, user_id)
);

-- message_edits: история редактирования сообщений
CREATE TABLE IF NOT EXISTS public.message_edits (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  old_content text,
  new_content text NOT NULL,
  edited_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- PART 3: RLS POLICIES
-- =============================================================

ALTER TABLE public.read_states ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_states_own ON public.read_states FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY reactions_select ON public.message_reactions FOR SELECT USING (true);
CREATE POLICY reactions_insert ON public.message_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY reactions_delete ON public.message_reactions FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE public.chat_pins ENABLE ROW LEVEL SECURITY;
CREATE POLICY pins_own ON public.chat_pins FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.message_edits ENABLE ROW LEVEL SECURITY;
CREATE POLICY edits_select ON public.message_edits FOR SELECT USING (true);
CREATE POLICY edits_insert ON public.message_edits FOR INSERT WITH CHECK (true);

-- =============================================================
-- PART 4: GRANT/REVOKE
-- =============================================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.read_states TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.message_reactions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_pins TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.message_edits TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO authenticated;

-- =============================================================
-- PART 5: Utility function
-- =============================================================

CREATE OR REPLACE FUNCTION exec_sql(query text) RETURNS jsonb AS $func$
DECLARE result jsonb;
BEGIN
  EXECUTE query INTO result;
  RETURN result;
EXCEPTION WHEN OTHERS THEN
  IF query ILIKE 'CREATE%' OR query ILIKE 'ALTER%' OR query ILIKE 'DROP%'
     OR query ILIKE 'GRANT%' OR query ILIKE 'REVOKE%'
     OR query ILIKE 'ALTER%'
  THEN
    EXECUTE query;
    RETURN jsonb_build_object('ok', true);
  ELSE
    RETURN jsonb_build_object('error', SQLERRM);
  END IF;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;
