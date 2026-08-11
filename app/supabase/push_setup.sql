-- Vibe: обновления схемы для продакшн-фич.
-- Применте в Supabase Dashboard -> SQL Editor (каждый блок отдельно или целиком).

-- 1) Био профиля
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS bio text NOT NULL DEFAULT '';

-- 2) Сториз
CREATE TABLE IF NOT EXISTS public.stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  photo_url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

-- ПРОФИЛИ: сейчас RLS, скорее всего, уже включена — добавьте policy, если её нет:
-- CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "stories_select" ON public.stories FOR SELECT
  USING (auth.role() = 'authenticated');
CREATE POLICY "stories_insert" ON public.stories FOR INSERT
  WITH CHECK (auth.uid() = profile_id);
CREATE POLICY "stories_delete" ON public.stories FOR DELETE
  USING (auth.uid() = profile_id);

-- Примечание о пушах (см. README):
-- реальная доставка FCM настраивается через Dashboard -> Database -> Webhooks:
--   Event: INSERT, Table: messages
--   Destination URL: https://<project-ref>.functions.supabase.co/send-push
-- Функция send-push обрабатывает payload dashboard-вебхука напрямую.