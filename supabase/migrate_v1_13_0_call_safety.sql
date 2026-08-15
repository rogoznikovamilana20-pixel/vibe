-- VIBE PHASE 11: CALL SAFETY + PRIVACY RLS
-- Project: rgdwfoicidnamejluxfx
-- Date: 2026-08-15
-- Status: APPLIED

-- =============================================================
-- 1. FIX profile_privacy RLS — was fully open (using(true), with check(true))
-- =============================================================

DROP POLICY IF EXISTS profile_privacy_all ON profile_privacy;

-- Users can read any profile privacy (public info like last_seen visibility)
CREATE POLICY profile_privacy_select ON profile_privacy
  FOR SELECT USING (true);

-- Users can only update/insert their OWN privacy row
CREATE POLICY profile_privacy_modify ON profile_privacy
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
