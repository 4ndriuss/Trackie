-- Migration: 20261020000001_secure_subscription_plan.sql
-- Description: Mengunci hak update paket langganan (plan, subscription_status, subscription_expires_at)
--              pada tabel public.profiles agar hanya dapat diubah oleh service_role (server/webhook),
--              mencegah privilege escalation saat registrasi, dan memvalidasi batas grup di backend.
-- Author: Trackie Engineering Team
-- Date: 2026-10-20

-- ==============================================================================
-- 1. Cabut Izin UPDATE Kolom Langganan dari Role 'authenticated' & 'anon'
-- ==============================================================================
-- Batalkan izin update umum pada seluruh kolom profiles
REVOKE UPDATE ON public.profiles FROM authenticated, anon, PUBLIC;

-- Berikan izin UPDATE HANYA pada kolom yang sah diubah oleh pengguna
GRANT UPDATE (
  name,
  vehicle,
  phone,
  birth_date,
  avatar_url,
  has_seen_subscription_page
) ON public.profiles TO authenticated;

-- ==============================================================================
-- 2. Trigger Perlindungan Server-Side: BEFORE UPDATE pada public.profiles
-- ==============================================================================
-- Memastikan jika ada request UPDATE pada kolom sensitif (plan, subscription_status,
-- subscription_expires_at), request TERSEBUT HARUS berasal dari 'service_role'.
CREATE OR REPLACE FUNCTION public.protect_profile_subscription_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Periksa apakah ada perubahan pada kolom sensitif langganan
  IF (NEW.plan IS DISTINCT FROM OLD.plan)
     OR (NEW.subscription_status IS DISTINCT FROM OLD.subscription_status)
     OR (NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at) THEN
    
    -- Verifikasi bahwa peran eksekutor saat ini adalah 'service_role' (bukan authenticated client)
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

-- ==============================================================================
-- 3. Amankan Trigger Registrasi: handle_new_user() (Cegah Injeksi Plan saat Daftar)
-- ==============================================================================
-- Kunci plan selalu bernilai 'free', status 'active', dan expires_at NULL.
-- Abaikan metadata plan/status yang dikirim dari client saat auth.signUp.
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
    plan, subscription_status, subscription_expires_at, has_seen_subscription_page
  )
  VALUES (
    NEW.id,
    LEFT(COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', 'User'), 100),
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'photo_url'),
    LEFT(COALESCE(NEW.raw_user_meta_data->>'vehicle', ''), 100),
    LEFT(COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone), 30),
    v_birth,
    'free', -- HARDENED: selalu free, abaikan client input
    'active', -- HARDENED: selalu active
    NULL,     -- HARDENED: tidak ada expires_at untuk free plan
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

-- ==============================================================================
-- 4. Validasi Batas Kuota Grup di Backend (Hanya Hitung Grup Aktif)
-- ==============================================================================
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

  -- Pengguna Premium aktif mendapatkan batas 20 grup
  IF lower(v_plan) = 'premium'
     AND lower(v_status) IN ('active', 'canceled')
     AND (v_expires_at IS NULL OR v_expires_at > now()) THEN
    v_max_groups := 20;
  ELSE
    v_max_groups := 2;
  END IF;

  -- Hitung HANYA grup yang berstatus 'active' (bukan yang sudah 'ended')
  SELECT count(*)
    INTO v_used_count
    FROM public.groups g
   WHERE p_uid::text = ANY (g.member_uids)
     AND g.status = 'active';

  RETURN v_used_count < v_max_groups;
END;
$$;

REVOKE ALL ON FUNCTION public.can_create_or_join_group(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_create_or_join_group(uuid) TO authenticated, service_role;
