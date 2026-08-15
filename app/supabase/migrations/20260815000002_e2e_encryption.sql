-- ============================================================
-- E2E Encryption: columns + key storage
-- ============================================================

-- Публичный ключ E2E в профиле
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS e2e_public_key TEXT;

-- Зашифрованное содержимое сообщения
ALTER TABLE messages ADD COLUMN IF NOT EXISTS encrypted_content TEXT;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN DEFAULT false;

-- RLS:Anyone can read public keys (for key exchange)
-- (profiles already has RLS, public_key is readable by authenticated users)
