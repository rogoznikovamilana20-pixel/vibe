-- Fix devices RLS for X3DH bundle fetch
-- devices_select was `auth.uid() = user_id` which blocks fetching other users' identity keys
-- for E2EE handshake. Bundle fetch must be readable by any authenticated user.
-- Keep insert/update/delete restricted to owner.

drop policy if exists devices_select on public.devices;

create policy devices_select on public.devices
    for select to authenticated
    using (true);

-- Keep other policies as is (insert/update/delete already owner-only)
-- No grants change needed
