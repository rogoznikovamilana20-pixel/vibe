-- ============================================================
-- E2E TABLES — apply missing migrations safely
-- Project: rgdwfoicidnamejluxfx
-- Date: 2026-08-17
-- All statements use IF NOT EXISTS / DROP IF EXISTS for safety
-- ============================================================

-- 1. user_security (from 20260815000000)
CREATE TABLE IF NOT EXISTS user_security (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  password_hash TEXT NOT NULL,
  hint          TEXT,
  enabled       BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE user_security ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_security_select ON user_security;
CREATE POLICY user_security_select ON user_security FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_security_insert ON user_security;
CREATE POLICY user_security_insert ON user_security FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_security_update ON user_security;
CREATE POLICY user_security_update ON user_security FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_security_delete ON user_security;
CREATE POLICY user_security_delete ON user_security FOR DELETE USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.check_2fa_enabled()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE((SELECT enabled FROM user_security WHERE user_id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.get_2fa_hint()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT hint FROM user_security WHERE user_id = auth.uid();
$$;

-- 2. phone_otps (from 20260815000001)
CREATE TABLE IF NOT EXISTS phone_otps (
  id          BIGSERIAL PRIMARY KEY,
  phone       TEXT NOT NULL,
  code        TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '5 minutes'),
  verified    BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_phone_otps_phone ON phone_otps (phone, verified, expires_at);
ALTER TABLE phone_otps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS phone_otps_service ON phone_otps;
CREATE POLICY phone_otps_service ON phone_otps FOR ALL USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.verify_phone_otp(p_phone TEXT, p_code TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_row phone_otps%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM phone_otps
  WHERE phone = p_phone AND verified = false AND expires_at > now()
  ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_row.code != p_code THEN RETURN false; END IF;
  UPDATE phone_otps SET verified = true WHERE id = v_row.id;
  RETURN true;
END;
$$;

-- 3. E2E columns (from 20260815000002) — fully safe
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS e2e_public_key TEXT;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS encrypted_content TEXT;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN DEFAULT false;

-- 4. E2EE V2 storage (from 20260815000003) — fully safe
ALTER TABLE messages ADD COLUMN IF NOT EXISTS e2ee_version INTEGER NOT NULL DEFAULT 1;
CREATE INDEX IF NOT EXISTS messages_e2ee_version_idx ON messages (e2ee_version) WHERE e2ee_version > 1;

-- 5. Storage private (from 20260810210000) — safe drop-then-create
UPDATE storage.buckets SET public = false WHERE id = 'avatars';
DROP POLICY IF EXISTS "avatars_all" ON storage.objects;
DROP POLICY IF EXISTS "media_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "media_update_own" ON storage.objects;
DROP POLICY IF EXISTS "media_delete_own" ON storage.objects;
DROP POLICY IF EXISTS "media_select" ON storage.objects;
DROP POLICY IF EXISTS "media_select_like" ON storage.objects;
DROP POLICY IF EXISTS "media_select_owner" ON storage.objects;
CREATE POLICY "media_insert_own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (owner_id::uuid = auth.uid());
CREATE POLICY "media_update_own" ON storage.objects FOR UPDATE TO authenticated
  USING (owner_id::uuid = auth.uid()) WITH CHECK (owner_id::uuid = auth.uid());
CREATE POLICY "media_delete_own" ON storage.objects FOR DELETE TO authenticated
  USING (owner_id::uuid = auth.uid());
CREATE POLICY "media_select_owner" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'avatars' AND owner_id IS NOT NULL AND owner_id::uuid = auth.uid());
