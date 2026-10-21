-- Rollback: 20261021000001_add_groups_member_uids_gin_index_rollback.sql
-- Description: Menghapus PostgreSQL GIN Index idx_groups_member_uids dari tabel public.groups.
-- Author: Trackie Engineering Team
-- Date: 2026-10-21

-- ==============================================================================
-- 1. Hapus GIN Index pada kolom member_uids di tabel public.groups (Idempotent)
-- ==============================================================================
DROP INDEX IF EXISTS public.idx_groups_member_uids;
