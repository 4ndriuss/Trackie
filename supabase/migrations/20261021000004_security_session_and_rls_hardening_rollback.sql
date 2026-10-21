-- Rollback Migration: 20261021000004_security_session_and_rls_hardening_rollback.sql

DROP FUNCTION IF EXISTS public.set_group_destination(uuid, text);

DROP POLICY IF EXISTS "profiles_select_group_members" ON public.profiles;

CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = id);

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
   WHERE p_uid::text = ANY (g.member_uids)
     AND g.status = 'active';

  RETURN v_used_count < v_max_groups;
END;
$$;
