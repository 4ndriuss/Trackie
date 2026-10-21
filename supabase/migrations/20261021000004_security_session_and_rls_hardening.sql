-- Migration: 20261021000004_security_session_and_rls_hardening.sql
-- Description: Implementasi Langkah 1 Keamanan:
--              1. BACK-04: Buka RLS SELECT profiles untuk sesama anggota grup aktif (profiles_select_group_members)
--              2. BACK-02: Advisory lock anti-race condition (TOCTOU) pada can_create_or_join_group dan join_group
--              3. BACK-03: RPC set_group_destination berotorisasi Host untuk mencegah pembajakan rute touring
-- Author: Trackie Engineering Team
-- Date: 2026-10-21

-- ==============================================================================
-- 1. Buka RLS SELECT Profiles untuk Sesama Rekan Rombongan (BACK-04)
-- ==============================================================================
-- Pengguna dapat melihat profil miliknya sendiri, ATAU profil anggota lain
-- yang berada dalam grup touring aktif yang sama.
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_group_members" ON public.profiles;

CREATE POLICY "profiles_select_group_members" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = id
    OR EXISTS (
      SELECT 1 FROM public.groups g
       WHERE g.status = 'active'
         AND (SELECT auth.uid())::text = ANY (g.member_uids)
         AND public.profiles.id::text = ANY (g.member_uids)
    )
  );

-- ==============================================================================
-- 2. Advisory Lock Transaksi Anti-TOCTOU pada Validasi Kuota Grup (BACK-02)
-- ==============================================================================
-- Mengunci ID pengguna selama transaksi berjalan sehingga concurrent request
-- (misal join simultan ke 2 grup) tidak dapat membypass kuota 2 grup paket Free.
CREATE OR REPLACE FUNCTION public.can_create_or_join_group(p_uid uuid)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
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

  -- Kunci level transaksi pada ID pengguna (Advisory Lock)
  PERFORM pg_advisory_xact_lock(hashtext(p_uid::text));

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

-- Perbarui RPC join_group dengan advisory lock eksplisit
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

  -- Kunci transaksi pengguna untuk mencegah TOCTOU
  PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));

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

-- ==============================================================================
-- 3. RPC Otorisasi Pembaruan Destinasi Grup oleh Host (BACK-03)
-- ==============================================================================
-- Memastikan perubahan destinasi konvoi hanya sah jika dieksekusi oleh host grup yang aktif
CREATE OR REPLACE FUNCTION public.set_group_destination(
  p_group_id uuid,
  p_destination text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.groups
     SET destination = trim(p_destination)
   WHERE id = p_group_id
     AND host_uid = auth.uid()
     AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya Host grup yang berhak mengubah titik tujuan atau grup telah berakhir.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.set_group_destination(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_group_destination(uuid, text) TO authenticated;
