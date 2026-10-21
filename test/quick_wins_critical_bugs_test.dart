import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackie/models/user_model.dart';
import 'package:trackie/providers/location_provider.dart';
import 'package:trackie/services/background_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quick Wins & Critical Bugs Contract Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('BUG-02: UserModel formats birth_date as YYYY-MM-DD without timestamp', () {
      final user = UserModel(
        uid: 'user_123',
        name: 'Test User',
        email: 'test@example.com',
        vehicle: 'Motor',
        phone: '08123456789',
        birthDate: DateTime(1995, 8, 17, 14, 30, 45),
        createdAt: DateTime(2026, 1, 1),
      );

      final supabaseMap = user.toSupabase();
      expect(supabaseMap['birth_date'], equals('1995-08-17'));

      final firestoreMap = user.toMap();
      expect(firestoreMap['birth_date'], equals('1995-08-17'));
    });

    test('BUG-02: UserModel handles null birth_date gracefully', () {
      final user = UserModel(
        uid: 'user_null_dob',
        name: 'No DOB',
        email: 'nodob@example.com',
        vehicle: 'Car',
        phone: '08123456780',
        birthDate: null,
        createdAt: DateTime(2026, 1, 1),
      );

      final supabaseMap = user.toSupabase();
      expect(supabaseMap['birth_date'], isNull);
    });

    test('BACK-02: LocationProvider manages Ghost Mode state and SharedPreferences persistence', () async {
      SharedPreferences.setMockInitialValues({'trackie_ghost_mode': false});
      final provider = LocationProvider();

      expect(provider.isGhostMode, isFalse);

      // Toggle to true
      await provider.setGhostMode(true);
      expect(provider.isGhostMode, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('trackie_ghost_mode'), isTrue);

      // Toggle back to false
      await provider.setGhostMode(false);
      expect(provider.isGhostMode, isFalse);
      expect(prefs.getBool('trackie_ghost_mode'), isFalse);
    });

    test('BACK-02: BackgroundLocationService.setGhostMode does not crash or throw in test env', () {
      expect(() => BackgroundLocationService.setGhostMode(true), returnsNormally);
      expect(() => BackgroundLocationService.setGhostMode(false), returnsNormally);
    });
  });
}
