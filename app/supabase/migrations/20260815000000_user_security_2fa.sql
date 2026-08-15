-- ============================================================
-- 2FA: user_security table + RLS + RPC
-- ============================================================

CREATE TABLE IF NOT EXISTS user_security (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  password_hash TEXT NOT NULL,
  hint          TEXT,
  enabled       BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_security ENABLE ROW LEVEL SECURITY;

-- Owner can read/write own row
CREATE POLICY user_security_select ON user_security
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_security_insert ON user_security
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_security_update ON user_security
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY user_security_delete ON user_security
  FOR DELETE USING (auth.uid() = user_id);

-- RPC: check if 2FA is enabled for current user
CREATE OR REPLACE FUNCTION public.check_2fa_enabled()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT enabled FROM user_security WHERE user_id = auth.uid()),
    false
  );
$$;

-- RPC: get 2FA hint for current user (nullable)
CREATE OR REPLACE FUNCTION public.get_2fa_hint()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT hint FROM user_security WHERE user_id = auth.uid();
$$;
