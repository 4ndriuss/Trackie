-- ========================================================
-- TRACKIE DATABASE SCHEMA & KEAMANAN (RLS + RPC) UNTUK SUPABASE
-- Jalankan skrip ini di: Supabase Dashboard -> SQL Editor -> Run
-- Skrip ini bersifat idempotent (aman dijalankan ulang kapan saja).
-- ========================================================

-- 1. Ekstensi PostGIS untuk fitur spasial & pemetaan
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Tabel Profil Pengguna (Sinkron dengan auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  vehicle TEXT DEFAULT '',
  phone TEXT,
  birth_date DATE,
  avatar_url TEXT,
  plan TEXT NOT NULL DEFAULT 'free', -- 'free' atau 'premium'
  subscription_status TEXT NOT NULL DEFAULT 'active', -- 'active', 'expired', 'canceled'
  subscription_expires_at TIMESTAMPTZ,
  has_seen_subscription_page BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pastikan semua kolom pada profiles tersedia
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS name TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS vehicle TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS birth_date DATE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS plan TEXT NOT NULL DEFAULT 'free';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS has_seen_subscription_page BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Trigger otomatis membuat profile saat user mendaftar di auth.users
-- (search_path dikunci demi keamanan SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_birth DATE;
BEGIN
  BEGIN
    v_birth := NULLIF(NEW.raw_user_meta_data->>'birth_date', '')::DATE;
  EXCEPTION WHEN OTHERS THEN
    v_birth := NULL;
  END;

  INSERT INTO public.profiles (
    id, name, email, avatar_url, vehicle, phone, birth_date,
    plan, subscription_status, has_seen_subscription_page
  )
  VALUES (
    NEW.id,
    LEFT(COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', 'User'), 100),
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'photo_url'),
    LEFT(COALESCE(NEW.raw_user_meta_data->>'vehicle', ''), 100),
    LEFT(COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone), 30),
    v_birth,
    'free', -- HARDENED: selalu free saat registrasi
    'active', -- HARDENED: selalu active
    COALESCE((NEW.raw_user_meta_data->>'has_seen_subscription_page')::boolean, false)
  )
  ON CONFLICT (id) DO UPDATE SET
    name       = EXCLUDED.name,
    email      = EXCLUDED.email,
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
    birth_date = COALESCE(EXCLUDED.birth_date, public.profiles.birth_date);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill: salin user yang sudah terlanjur terdaftar di auth.users sebelum trigger dipasang ke tabel profiles
INSERT INTO public.profiles (id, name, email, avatar_url, vehicle, phone)
SELECT
  u.id,
  LEFT(COALESCE(u.raw_user_meta_data->>'name', u.raw_user_meta_data->>'full_name', 'User'), 100),
  COALESCE(u.email, ''),
  COALESCE(u.raw_user_meta_data->>'avatar_url', u.raw_user_meta_data->>'photo_url'),
  LEFT(COALESCE(u.raw_user_meta_data->>'vehicle', ''), 100),
  LEFT(COALESCE(u.raw_user_meta_data->>'phone', u.phone), 30)
FROM auth.users u
ON CONFLICT (id) DO NOTHING;

-- 3. Tabel Grup Perjalanan
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'motor',
  destination TEXT NOT NULL,
  invite_code VARCHAR(12) UNIQUE NOT NULL,
  host_uid UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  member_uids TEXT[] DEFAULT '{}',
  status TEXT DEFAULT 'active', -- 'active' atau 'ended'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

-- Pastikan kolom baru tersedia jika tabel groups sudah terlanjur dibuat sebelumnya
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS member_uids TEXT[] DEFAULT '{}';
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ;
ALTER TABLE public.groups ALTER COLUMN invite_code TYPE VARCHAR(12);

CREATE INDEX IF NOT EXISTS idx_groups_invite_code ON public.groups (invite_code);
CREATE INDEX IF NOT EXISTS idx_groups_status ON public.groups (status);
CREATE INDEX IF NOT EXISTS idx_groups_member_uids ON public.groups USING gin (member_uids);

-- Fungsi Validasi Batas Grup Berdasarkan Plan Subscription (Server-Side Enforcement)
-- Free: maks 2 grup | Premium Aktif: maks 20 grup
CREATE OR REPLACE FUNCTION public.can_create_or_join_group(p_uid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_plan       text := 'free';
  v_status     text := 'active';
  v_expires_at timestamptz;
  v_max_groups int  := 2;
  v_used_count int  := 0;
BEGIN
  IF p_uid IS NULL THEN
    RETURN false;
  END IF;

  SELECT coalesce(plan, 'free'),
         coalesce(subscription_status, 'active'),
         subscription_expires_at
    INTO v_plan, v_status, v_expires_at
    FROM public.profiles
   WHERE id = p_uid;

  IF lower(v_plan) = 'premium'
     AND lower(v_status) IN ('active', 'canceled')
     AND (v_expires_at IS NULL OR v_expires_at > now()) THEN
    v_max_groups := 20;
  ELSE
    v_max_groups := 2;
  END IF;

  -- Hitung hanya grup yang berstatus 'active' (bukan yang sudah 'ended')
  SELECT count(*)
    INTO v_used_count
    FROM public.groups g
   WHERE p_uid::text = ANY (g.member_uids)
     AND g.status = 'active';

  RETURN v_used_count < v_max_groups;
END;
$$;

REVOKE ALL ON FUNCTION public.can_create_or_join_group(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_create_or_join_group(uuid) TO authenticated;

-- 4. Tabel Riwayat Perjalanan (Trip History)
CREATE TABLE IF NOT EXISTS public.trip_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  group_name TEXT NOT NULL DEFAULT '',
  group_type TEXT NOT NULL DEFAULT 'motor',
  distance_km DOUBLE PRECISION DEFAULT 0.0,
  duration TEXT DEFAULT '',
  route_path JSONB DEFAULT '[]'::jsonb,
  member_count INT DEFAULT 1,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ DEFAULT NOW(),
  journal_note TEXT,
  rating DOUBLE PRECISION
);

-- Pastikan kolom baru tersedia jika tabel trip_history sudah terlanjur dibuat sebelumnya
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS group_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS group_type TEXT NOT NULL DEFAULT 'motor';
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS distance_km DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS duration TEXT DEFAULT '';
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS route_path JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS member_count INT DEFAULT 1;
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS journal_note TEXT;
ALTER TABLE public.trip_history ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trip_history' AND column_name = 'title'
  ) THEN
    ALTER TABLE public.trip_history ALTER COLUMN title DROP NOT NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_trip_history_user ON public.trip_history (user_id, started_at DESC);

-- 5. Row Level Security (RLS) & Policies
ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;

CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = id);
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = id);
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id) WITH CHECK ((SELECT auth.uid()) = id);

-- Batasi hak UPDATE: cabut update umum, hanya izinkan kolom profil non-sensitif
REVOKE UPDATE ON public.profiles FROM authenticated, anon, PUBLIC;
GRANT UPDATE (
  name, vehicle, phone, birth_date, avatar_url, has_seen_subscription_page
) ON public.profiles TO authenticated;

-- Trigger proteksi: cegah modifikasi kolom langganan selain oleh service_role
CREATE OR REPLACE FUNCTION public.protect_profile_subscription_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF (NEW.plan IS DISTINCT FROM OLD.plan)
     OR (NEW.subscription_status IS DISTINCT FROM OLD.subscription_status)
     OR (NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at) THEN
    IF COALESCE(auth.role(), '') != 'service_role' THEN
      RAISE EXCEPTION 'Akses ditolak: Kolom paket dan langganan hanya dapat diperbarui oleh sistem / service role backend.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_subscription ON public.profiles;
CREATE TRIGGER trg_protect_profile_subscription
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_subscription_fields();
CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "groups_select_members" ON public.groups;
DROP POLICY IF EXISTS "groups_insert_as_host" ON public.groups;
DROP POLICY IF EXISTS "groups_update_as_host" ON public.groups;

CREATE POLICY "groups_select_members" ON public.groups
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid())::text = ANY (member_uids));

CREATE POLICY "groups_insert_as_host" ON public.groups
  FOR INSERT TO authenticated
  WITH CHECK (
    host_uid = (SELECT auth.uid())
    AND member_uids = ARRAY[(SELECT auth.uid())::text]
    AND status = 'active'
    AND ended_at IS NULL
    AND public.can_create_or_join_group((SELECT auth.uid()))
  );

CREATE POLICY "groups_update_as_host" ON public.groups
  FOR UPDATE TO authenticated
  USING (host_uid = (SELECT auth.uid()))
  WITH CHECK (host_uid = (SELECT auth.uid()));

DROP POLICY IF EXISTS "trip_history_own" ON public.trip_history;

CREATE POLICY "trip_history_own" ON public.trip_history
  FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 6. RPC Keanggotaan Grup & Hapus Akun (Atomik & Divalidasi di Server)
CREATE OR REPLACE FUNCTION public.join_group(p_invite_code text)
RETURNS SETOF public.groups
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_group public.groups;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO v_group
    FROM public.groups
   WHERE invite_code = upper(trim(p_invite_code))
     AND status = 'active'
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Jika user belum menjadi anggota grup ini, validasi batas kuota grup berdasarkan plan
  IF NOT (v_uid::text = ANY (v_group.member_uids)) THEN
    IF NOT public.can_create_or_join_group(v_uid) THEN
      RAISE EXCEPTION 'GROUP_LIMIT_REACHED: Kamu sudah mencapai batas jumlah grup untuk paket saat ini.';
    END IF;
  END IF;

  RETURN QUERY
  UPDATE public.groups
     SET member_uids = CASE
           WHEN v_uid::text = ANY (member_uids) THEN member_uids
           ELSE array_append(member_uids, v_uid::text)
         END
   WHERE id = v_group.id
  RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_group(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_group     public.groups;
  v_remaining text[];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO v_group FROM public.groups WHERE id = p_group_id FOR UPDATE;
  IF NOT FOUND OR NOT (v_uid::text = ANY (v_group.member_uids)) THEN
    RETURN;
  END IF;

  v_remaining := array_remove(v_group.member_uids, v_uid::text);

  IF coalesce(array_length(v_remaining, 1), 0) = 0 THEN
    UPDATE public.groups
       SET member_uids = v_remaining, status = 'ended', ended_at = now()
     WHERE id = p_group_id;
  ELSE
    UPDATE public.groups
       SET member_uids = v_remaining,
           host_uid = CASE WHEN v_group.host_uid = v_uid
                           THEN v_remaining[1]::uuid
                           ELSE v_group.host_uid END
     WHERE id = p_group_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.end_group(p_group_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE public.groups
     SET status = 'ended', ended_at = now()
   WHERE id = p_group_id
     AND host_uid = auth.uid()
     AND status = 'active';
$$;

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- 1. Akhiri semua grup aktif di mana user adalah host (mencegah zombie headless groups)
  UPDATE public.groups
     SET status = 'ended',
         ended_at = now()
   WHERE host_uid = v_uid
     AND status = 'active';

  -- 2. Keluarkan user dari daftar anggota di semua grup
  UPDATE public.groups
     SET member_uids = array_remove(member_uids, v_uid::text)
   WHERE v_uid::text = ANY (member_uids);

  -- 3. Hapus data auth user (cascade ke public.profiles dan data terkait)
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.join_group(text)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.leave_group(uuid)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.end_group(uuid)         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_my_account()     FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_group(text)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_group(uuid)    TO authenticated;
GRANT EXECUTE ON FUNCTION public.end_group(uuid)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account()  TO authenticated;

-- 7. Storage Bucket untuk Avatar Pengguna (Batas 5 MB & Whitelist MIME Type)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "Public avatar access" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

CREATE POLICY "Public avatar access" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (SELECT auth.uid())::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own avatar" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (SELECT auth.uid())::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own avatar" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND (SELECT auth.uid())::text = (storage.foldername(name))[1]);

-- 8. Realtime Publication
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'groups') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.groups;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'trip_history') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_history;
  END IF;
END $$;

-- 9. Otorisasi Realtime Broadcast (Private Channel) untuk Live Tracking
CREATE OR REPLACE FUNCTION public.can_access_tracking_topic(p_topic text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_group_id uuid;
BEGIN
  IF p_topic IS NULL OR p_topic NOT LIKE 'group_tracking:%' THEN
    RETURN false;
  END IF;

  BEGIN
    v_group_id := substring(p_topic FROM 16)::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN false;
  END;

  RETURN EXISTS (
    SELECT 1 FROM public.groups g
     WHERE g.id = v_group_id
       AND g.status = 'active'
       AND (SELECT auth.uid())::text = ANY (g.member_uids)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.can_access_tracking_topic(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_access_tracking_topic(text) TO authenticated;

DROP POLICY IF EXISTS "tracking_members_receive" ON realtime.messages;
DROP POLICY IF EXISTS "tracking_members_send"    ON realtime.messages;

CREATE POLICY "tracking_members_receive" ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    realtime.messages.extension = 'broadcast'
    AND public.can_access_tracking_topic((SELECT realtime.topic()))
  );

CREATE POLICY "tracking_members_send" ON realtime.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    realtime.messages.extension = 'broadcast'
    AND public.can_access_tracking_topic((SELECT realtime.topic()))
  );
