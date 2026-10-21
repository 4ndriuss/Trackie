-- Migration: 20261021000002_fix_delete_my_account_zombie_groups.sql
-- Description: Mencegah zombie active groups ketika Host menghapus akunnya via delete_my_account() (BACK-01).
--              Otomatis menutup grup aktif (status = 'ended', ended_at = now()) yang di-host oleh pengguna,
--              membebaskan kuota grup aktif bagi anggota yang tersisa, dan mencegah orphaned rows.
-- Author: Trackie Engineering Team
-- Date: 2026-10-21

-- ==============================================================================
-- Perbarui fungsi RPC public.delete_my_account()
-- ==============================================================================
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

  -- 1. Akhiri semua grup aktif di mana user adalah host
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

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
