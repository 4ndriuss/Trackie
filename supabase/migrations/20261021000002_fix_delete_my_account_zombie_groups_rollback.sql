-- Rollback Migration: 20261021000002_fix_delete_my_account_zombie_groups_rollback.sql
-- Description: Mengembalikan public.delete_my_account() ke versi sebelumnya tanpa auto-end hosted groups.

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

  UPDATE public.groups
     SET member_uids = array_remove(member_uids, v_uid::text)
   WHERE v_uid::text = ANY (member_uids);

  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
