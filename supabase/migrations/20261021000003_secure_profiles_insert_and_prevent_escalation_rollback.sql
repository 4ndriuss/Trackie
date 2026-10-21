-- Rollback Migration: 20261021000003_secure_profiles_insert_and_prevent_escalation_rollback.sql

DROP FUNCTION IF EXISTS public.dev_simulate_subscription(text, text, timestamptz);

DROP TRIGGER IF EXISTS trg_protect_profile_subscription ON public.profiles;

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

CREATE TRIGGER trg_protect_profile_subscription
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_subscription_fields();

CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = id);
