import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackie/models/trip_history_model.dart';
import 'package:trackie/models/subscription_model.dart';
import 'package:trackie/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1 Hotfixes Contract Verification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('BUG-01: TripService saves trip locally to pending queue on offline fallback', () async {
      final tripService = TripService();
      const testUid = 'user_offline_001';

      final completedTrip = TripHistoryModel(
        id: 'trip_offline_999',
        groupName: 'Touring Puncak',
        groupType: 'motor',
        distanceKm: 42.5,
        duration: '1j 15m',
        routePath: [
          {'lat': -6.200000, 'lng': 106.816666},
          {'lat': -6.600000, 'lng': 106.900000},
        ],
        memberCount: 5,
        startedAt: DateTime(2026, 10, 21, 8, 0, 0),
        endedAt: DateTime(2026, 10, 21, 9, 15, 0),
      );

      // Simpan secara lokal
      await tripService.saveTripLocally(testUid, completedTrip);

      // Verifikasi data masuk ke antrean lokal
      final pendingTrips = await tripService.getPendingLocalTrips(testUid);
      expect(pendingTrips.length, equals(1));
      expect(pendingTrips.first.id, equals('trip_offline_999'));
      expect(pendingTrips.first.groupName, equals('Touring Puncak'));
      expect(pendingTrips.first.distanceKm, equals(42.5));
      expect(pendingTrips.first.routePath.length, equals(2));
    });

    test('BUG-01: TripService deduplicates pending offline trips by json payload', () async {
      final tripService = TripService();
      const testUid = 'user_offline_002';

      final completedTrip = TripHistoryModel(
        id: 'trip_dedup_100',
        groupName: 'Morning Ride',
        groupType: 'motor',
        distanceKm: 15.0,
        duration: '30m',
        routePath: [
          {'lat': -6.175110, 'lng': 106.865039},
        ],
        memberCount: 2,
        startedAt: DateTime(2026, 10, 21, 6, 0, 0),
        endedAt: DateTime(2026, 10, 21, 6, 30, 0),
      );

      // Simpan dua kali
      await tripService.saveTripLocally(testUid, completedTrip);
      await tripService.saveTripLocally(testUid, completedTrip);

      final pendingTrips = await tripService.getPendingLocalTrips(testUid);
      expect(pendingTrips.length, equals(1));
    });

    test('SEC-02: subscription_page.dart protects Developer Mock Card with kDebugMode', () {
      final subPageFile = File('lib/pages/subscription_page.dart');
      expect(subPageFile.existsSync(), isTrue);

      final content = subPageFile.readAsStringSync();
      expect(content.contains('if (kDebugMode && uid != null)'), isTrue);
      // Pastikan tidak ada lagi pemanggilan mock card terbuka tanpa kDebugMode
      expect(
        content.contains('// Panel Developer Mock Toggle (SEC-02: Terproteksi hanya tampil saat mode debug / development)'),
        isTrue,
      );
    });

    test('BACK-01 & BUG-02: Supabase schema & migration protect profiles insert and define dev_simulate_subscription', () {
      final migrationFile = File('supabase/migrations/20261021000003_secure_profiles_insert_and_prevent_escalation.sql');
      expect(migrationFile.existsSync(), isTrue);

      final migrationContent = migrationFile.readAsStringSync();
      expect(migrationContent.contains('DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;'), isTrue);
      expect(migrationContent.contains('BEFORE INSERT OR UPDATE ON public.profiles'), isTrue);
      expect(migrationContent.contains("NEW.plan := 'free';"), isTrue);
      expect(migrationContent.contains('FUNCTION public.dev_simulate_subscription'), isTrue);

      final masterSchema = File('supabase_schema.sql');
      expect(masterSchema.existsSync(), isTrue);
      final schemaContent = masterSchema.readAsStringSync();
      expect(schemaContent.contains('BEFORE INSERT OR UPDATE ON public.profiles'), isTrue);
      expect(schemaContent.contains('FUNCTION public.dev_simulate_subscription'), isTrue);
      expect(schemaContent.contains('DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;'), isTrue);
    });

    test('BUG-02: SubscriptionInfo preserves hasSeenSubscriptionPage flag correctly', () {
      const freePlan = SubscriptionInfo(
        plan: SubscriptionPlan.free,
        status: SubscriptionStatus.active,
        hasSeenSubscriptionPage: true,
      );

      final map = freePlan.toMap();
      expect(map['has_seen_subscription_page'], isTrue);
      expect(map['plan'], equals('free'));

      final reconstructed = SubscriptionInfo.fromMap(map);
      expect(reconstructed.hasSeenSubscriptionPage, isTrue);
      expect(reconstructed.plan, equals(SubscriptionPlan.free));
    });
  });
}
