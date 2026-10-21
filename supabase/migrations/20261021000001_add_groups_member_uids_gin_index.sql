-- Migration: 20261021000001_add_groups_member_uids_gin_index.sql
-- Description: Menambahkan PostgreSQL GIN Index pada kolom array member_uids di tabel public.groups
--              untuk mempercepat evaluasi RLS, kueri filter PostgREST (.contains), dan mencegah Full Table Scan (PERF-07).
-- Author: Trackie Engineering Team
-- Date: 2026-10-21

-- ==============================================================================
-- 1. Buat GIN Index pada kolom member_uids di tabel public.groups (Idempotent)
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_groups_member_uids
  ON public.groups USING gin (member_uids);

-- ==============================================================================
-- 2. Dokumentasi Metadata Indeks
-- ==============================================================================
COMMENT ON INDEX public.idx_groups_member_uids IS 'GIN index on public.groups(member_uids) array column for high-performance membership filtering and RLS evaluation (PERF-07).';
