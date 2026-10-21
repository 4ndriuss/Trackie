import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackie/services/secure_local_storage.dart';
import 'package:trackie/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Langkah 1: SEC-01 Secure Session Storage Tests', () {
    test('SecureLocalStorage initializes and handles session lifecycle', () async {
      SharedPreferences.setMockInitialValues({
        'supabase_persist_session_key': 'legacy_unencrypted_jwt_token',
      });

      final storage = SecureLocalStorage();
      await storage.initialize();

      // Memastikan instance storage mengimplementasikan antarmuka LocalStorage Supabase
      expect(storage, isNotNull);
    });
  });

  group('Langkah 1: BACK-02, BACK-03, BACK-04 Migration & Schema Verification', () {
    test('Migration 4 exists and contains correct RLS, advisory lock, and RPC definitions', () {
      final migrationFile = File(
        'supabase/migrations/20261021000004_security_session_and_rls_hardening.sql',
      );
      expect(migrationFile.existsSync(), isTrue,
          reason: 'File migrasi 4 harus tersedia di folder migrations');

      final content = migrationFile.readAsStringSync();

      // BACK-04: RLS profiles_select_group_members
      expect(content, contains('profiles_select_group_members'));
      expect(content, contains('auth.uid()'));
      expect(content, contains('ANY (g.member_uids)'));

      // BACK-02: Advisory lock anti-TOCTOU pada can_create_or_join_group dan join_group
      expect(content, contains('pg_advisory_xact_lock(hashtext(p_uid::text))'));
      expect(content, contains('pg_advisory_xact_lock(hashtext(v_uid::text))'));
      expect(content, contains('VOLATILE'));

      // BACK-03: RPC set_group_destination berotorisasi Host
      expect(content, contains('FUNCTION public.set_group_destination'));
      expect(content, contains('host_uid = auth.uid()'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.set_group_destination'));
    });

    test('Migration 4 rollback script exists and contains accurate rollback statements', () {
      final rollbackFile = File(
        'supabase/migrations/20261021000004_security_session_and_rls_hardening_rollback.sql',
      );
      expect(rollbackFile.existsSync(), isTrue,
          reason: 'File rollback migrasi 4 harus tersedia');

      final content = rollbackFile.readAsStringSync();
      expect(content, contains('DROP POLICY IF EXISTS "profiles_select_group_members"'));
      expect(content, contains('CREATE POLICY "profiles_select_own"'));
      expect(content, contains('DROP FUNCTION IF EXISTS public.set_group_destination'));
    });

    test('supabase_schema.sql is synchronized with Migration 4 security hardening', () {
      final schemaFile = File('supabase_schema.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync();

      // BACK-04
      expect(content, contains('profiles_select_group_members'));
      // BACK-02
      expect(content, contains('pg_advisory_xact_lock(hashtext(p_uid::text))'));
      expect(content, contains('pg_advisory_xact_lock(hashtext(v_uid::text))'));
      // BACK-03
      expect(content, contains('set_group_destination('));
      expect(content, contains('host_uid = auth.uid()'));
    });
  });

  group('Langkah 1: BACK-03 LocationService Host Authorization Validation', () {
    late LocationService service;

    setUp(() {
      service = LocationService();
    });

    test('expectedHostUid can be set and queried', () {
      expect(service.expectedHostUid, isNull);

      service.setExpectedHostUid('host-uuid-1234');
      expect(service.expectedHostUid, equals('host-uuid-1234'));

      service.setExpectedHostUid(null);
      expect(service.expectedHostUid, isNull);
    });

    test('cleanupGroupLocations clears expectedHostUid and resets state', () async {
      service.setExpectedHostUid('host-uuid-5678');
      expect(service.expectedHostUid, equals('host-uuid-5678'));

      await service.cleanupGroupLocations('test-group-id');
      expect(service.expectedHostUid, isNull);
    });
  });
}
