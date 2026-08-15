-- ============================================================
-- SMS OTP: таблица кодов + RLS + RPC
-- ============================================================

CREATE TABLE IF NOT EXISTS phone_otps (
  id          BIGSERIAL PRIMARY KEY,
  phone       TEXT NOT NULL,
  code        TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '5 minutes'),
  verified    BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_phone_otps_phone ON phone_otps (phone, verified, expires_at);

ALTER TABLE phone_otps ENABLE ROW LEVEL SECURITY;

-- Service role only (Edge Functions use service key)
CREATE POLICY phone_otps_service ON phone_otps
  FOR ALL USING (true)
  WITH CHECK (true);

-- RPC: verify OTP code. Returns true if valid and not expired.
CREATE OR REPLACE FUNCTION public.verify_phone_otp(
  p_phone TEXT,
  p_code  TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row phone_otps%ROWTYPE;
BEGIN
  SELECT * INTO v_row
  FROM phone_otps
  WHERE phone = p_phone
    AND verified = false
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_row.code != p_code THEN
    RETURN false;
  END IF;

  UPDATE phone_otps SET verified = true WHERE id = v_row.id;
  RETURN true;
END;
$$;
