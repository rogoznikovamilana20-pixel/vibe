-- ============================================================
-- E2EE V2: Storage contract — version discriminator
-- ============================================================
-- Adds e2ee_version to messages table.
-- Default 1 = V1 (existing E2EE behavior).
-- V2 messages will set e2ee_version = 2 explicitly.
-- Backward-compatible: existing rows unchanged (default 1).

ALTER TABLE messages ADD COLUMN IF NOT EXISTS e2ee_version INTEGER NOT NULL DEFAULT 1;

-- Index for filtering V2 messages (optional, for future queries)
CREATE INDEX IF NOT EXISTS messages_e2ee_version_idx ON messages (e2ee_version) WHERE e2ee_version > 1;
