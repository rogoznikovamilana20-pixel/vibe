-- Migration: E2EE V2 – identity keys, signed prekeys, one-time prekeys
-- Idempotent (IF NOT EXISTS)

-- ── Table: devices ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS devices (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    device_name          TEXT NOT NULL,
    identity_key_public  TEXT NOT NULL,          -- Base64 Ed25519 public key
    identity_dh_public   TEXT NOT NULL,          -- Base64 X25519 public key
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_active_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_revoked           BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT devices_user_identity_unique UNIQUE (user_id, identity_key_public)
);

CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);

-- ── Table: signed_prekeys ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS signed_prekeys (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id     UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    public_key    TEXT NOT NULL,          -- Base64 X25519 public key
    signature     TEXT NOT NULL,          -- Base64 Ed25519 signature
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active     BOOLEAN NOT NULL DEFAULT true,
    algorithm     TEXT NOT NULL DEFAULT 'ed25519+sha512'
);

CREATE INDEX IF NOT EXISTS idx_signed_prekeys_device_id ON signed_prekeys(device_id);
CREATE INDEX IF NOT EXISTS idx_signed_prekeys_active    ON signed_prekeys(device_id, is_active) WHERE is_active = true;

-- ── Table: one_time_prekeys ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS one_time_prekeys (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id     UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    public_key    TEXT NOT NULL,          -- Base64 X25519 public key
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    consumed_at   TIMESTAMPTZ NULL       -- NULL = available
);

CREATE INDEX IF NOT EXISTS idx_one_time_prekeys_device     ON one_time_prekeys(device_id);
CREATE INDEX IF NOT EXISTS idx_one_time_prekeys_available  ON one_time_prekeys(device_id) WHERE consumed_at IS NULL;

-- ── RLS: devices ───────────────────────────────────────────────────────────────

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY devices_select ON devices
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY devices_insert ON devices
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY devices_update ON devices
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY devices_delete ON devices
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- ── RLS: signed_prekeys ────────────────────────────────────────────────────────

ALTER TABLE signed_prekeys ENABLE ROW LEVEL SECURITY;

CREATE POLICY signed_prekeys_select ON signed_prekeys
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY signed_prekeys_insert ON signed_prekeys
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = (SELECT user_id FROM devices WHERE id = device_id));

CREATE POLICY signed_prekeys_update ON signed_prekeys
    FOR UPDATE TO authenticated
    USING (auth.uid() = (SELECT user_id FROM devices WHERE id = device_id));

CREATE POLICY signed_prekeys_delete ON signed_prekeys
    FOR DELETE TO authenticated
    USING (auth.uid() = (SELECT user_id FROM devices WHERE id = device_id));

-- ── RLS: one_time_prekeys ──────────────────────────────────────────────────────

ALTER TABLE one_time_prekeys ENABLE ROW LEVEL SECURITY;

CREATE POLICY one_time_prekeys_select ON one_time_prekeys
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY one_time_prekeys_insert ON one_time_prekeys
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = (SELECT user_id FROM devices WHERE id = device_id));

CREATE POLICY one_time_prekeys_update ON one_time_prekeys
    FOR UPDATE TO authenticated
    USING (auth.uid() = (SELECT user_id FROM devices WHERE id = device_id));

-- ── Grants ─────────────────────────────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE, DELETE ON devices           TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON signed_prekeys   TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON one_time_prekeys TO authenticated;
