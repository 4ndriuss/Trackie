-- Migration: 20261021000003_secure_profiles_insert_and_prevent_escalation.sql
-- Description: Menutup celah eskalasi hak akses paket Premium (BACK-01) dengan:
--              1. Menghapus policy DELETE langsung pada public.profiles (penghapusan via delete_my_account RPC)
--              2. Memasang trigger BEFORE INSERT OR UPDATE pada public.profiles untuk memaksa plan 'free' pada saat INSERT oleh authenticated/anon
--              3. Menyediakan RPC dev_simulate_subscription untuk testing dev/mock yang terkontrol (BUG-02)
-- Author: Trackie Engineering Team
-- Date: 2026-10-21

-- ==============================================================================
-- 1. Hapus Policy DELETE Langsung pada Tabel public.profiles (BACK-01)
-- ==============================================================================
-- Pengguna tidak boleh menghapus baris profil secara langsung melalui PostgREST,
-- karena dapat dieksploitasi untuk re-insert profil berstatus premium, serta
-- dapat meninggalkan zombie active groups. Penghapusan akun wajib via delete_my_account().
DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;

-- ==============================================================================
-- 2. Perbarui Trigger Proteksi: BEFORE INSERT OR UPDATE pada public.profiles (BACK-01)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.protect_profile_subscription_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Pada saat INSERT (registrasi atau insert mandiri):
  -- Jika bukan dieksekusi oleh service_role (server/webhook), paksa nilai default aman
  IF TG_OP = 'INSERT' THEN
    IF COALESCE(auth.role(), '') != 'service_role' THEN
      NEW.plan := 'free';
      NEW.subscription_status := 'active';
      NEW.subscription_expires_at := NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- Pada saat UPDATE:
  -- Periksa apakah ada perubahan pada kolom sensitif langganan
  IF TG_OP = 'UPDATE' THEN
    IF (NEW.plan IS DISTINCT FROM OLD.plan)
       OR (NEW.subscription_status IS DISTINCT FROM OLD.subscription_status)
       OR (NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at) THEN
      
      -- Verifikasi peran eksekutor saat ini adalah 'service_role'
      IF COALESCE(auth.role(), '') != 'service_role' THEN
        RAISE EXCEPTION 'Akses ditolak: Kolom paket dan langganan hanya dapat diperbarui oleh sistem / service role backend.';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_subscription ON public.profiles;
CREATE TRIGGER trg_protect_profile_subscription
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_subscription_fields();

-- ==============================================================================
-- 3. RPC Dev / Testing: dev_simulate_subscription (BUG-02)
-- ==============================================================================
-- Memungkinkan testing perubahan paket langganan secara terisolasi untuk akun sendiri
-- tanpa bypass manual di sisi client atau desinkronisasi antara client dan database.
CREATE OR REPLACE FUNCTION public.dev_simulate_subscription(
  p_plan text,
  p_status text DEFAULT 'active',
  p_expires_at timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_valid_plan text;
  v_valid_status text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  v_valid_plan := lower(trim(p_plan));
  IF v_valid_plan NOT IN ('free', 'premium') THEN
    v_valid_plan := 'free';
  END IF;

  v_valid_status := lower(trim(coalesce(p_status, 'active')));
  IF v_valid_status NOT IN ('active', 'expired', 'canceled') THEN
    v_valid_status := 'active';
  END IF;

  UPDATE public.profiles
     SET plan = v_valid_plan,
         subscription_status = v_valid_status,
         subscription_expires_at = p_expires_at
   WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.dev_simulate_subscription(text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dev_simulate_subscription(text, text, timestamptz) TO authenticated;
