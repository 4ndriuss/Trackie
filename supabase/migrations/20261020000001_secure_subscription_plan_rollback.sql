-- Rollback: 20261020000001_secure_subscription_plan_rollback.sql
-- Description: Mengembalikan izin dan fungsi skema profiles ke konfigurasi sebelum migrasi.
-- Author: Trackie Engineering Team
-- Date: 2026-10-20

-- 1. Hapus trigger dan fungsi proteksi kolom langganan
DROP TRIGGER IF EXISTS trg_protect_profile_subscription ON public.profiles;
DROP FUNCTION IF EXISTS public.protect_profile_subscription_fields();

-- 2. Kembalikan izin UPDATE penuh pada public.profiles untuk role authenticated
GRANT UPDATE ON public.profiles TO authenticated;

-- 3. Kembalikan handle_new_user() ke versi sebelumnya
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
    COALESCE(NEW.raw_user_meta_data->>'plan', 'free'),
    COALESCE(NEW.raw_user_meta_data->>'subscription_status', 'active'),
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

-- 4. Kembalikan can_create_or_join_group ke versi tanpa filter status
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

  SELECT count(*)
    INTO v_used_count
    FROM public.groups g
   WHERE p_uid::text = ANY (g.member_uids);

  RETURN v_used_count < v_max_groups;
END;
$$;
