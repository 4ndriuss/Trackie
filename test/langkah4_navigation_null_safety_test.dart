import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackie/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Langkah 4: BUG-03 AuthProvider Null-Safety & Async Gap Tests', () {
    test('updateProfilePicture returns false safely without throwing bang operator exception when user is null', () async {
      final provider = AuthProvider();

      // Memastikan bahwa pemanggilan tanpa user login tidak melempar Null check operator used on null value
      final result = await provider.updateProfilePicture(Uint8List(0), 'jpg');
      expect(result, isFalse);
    });

    test('updateProfile returns false safely without throwing bang operator exception when user is null', () async {
      final provider = AuthProvider();

      // Memastikan pemanggilan tanpa user login tidak melempar exception
      final result = await provider.updateProfile(name: 'New Name', vehicle: 'Motor');
      expect(result, isFalse);
    });
  });

  group('Langkah 4: BUG-04 MapPage SOS Mounted Guard Static Check', () {
    test('MapPage triggerSOS has if (!mounted) return; before calling setState', () {
      final file = File('lib/pages/map_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final sosTriggerIndex = content.indexOf('await locationProvider.triggerSOS(');
      expect(sosTriggerIndex, isNonNegative);

      final postTriggerSnippet = content.substring(sosTriggerIndex, sosTriggerIndex + 250);
      expect(postTriggerSnippet, contains('if (!mounted) return;'));
      expect(postTriggerSnippet, contains('setState(() {'));
    });
  });

  group('Langkah 4: BUG-05 Declarative Root Navigation Consistency Tests', () {
    test('LoginPage routes to root / instead of removing root stack', () {
      final file = File('lib/pages/login_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      // Pastikan semua pushNamedAndRemoveUntil merujuk ke root / (AuthWrapper)
      expect(content, isNot(contains("pushNamedAndRemoveUntil(\n              targetRoute")));
      expect(content, contains("pushNamedAndRemoveUntil(\n              '/'"));
    });

    test('SubscriptionPage first time flow resets to root /', () {
      final file = File('lib/pages/subscription_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, isNot(contains("pushNamedAndRemoveUntil('/home'")));
      expect(content, contains("pushNamedAndRemoveUntil('/', (route) => false)"));
    });

    test('ProfileTab logout resets to root /', () {
      final file = File('lib/pages/profile_tab.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, isNot(contains("pushNamedAndRemoveUntil(context, '/login'")));
      expect(content, contains("pushNamedAndRemoveUntil(context, '/', (route) => false)"));
    });

    test('AccountPage delete account resets to root /', () {
      final file = File('lib/pages/account_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, isNot(contains("pushNamedAndRemoveUntil(context, '/login'")));
      expect(content, contains("pushNamedAndRemoveUntil(context, '/', (route) => false)"));
    });
  });

  group('Langkah 4: BUG-06 & BUG-07 Edge Case Resilience Tests', () {
    test('TripDetailPage checks hasDistinctPoints before calling CameraFit.bounds', () {
      final file = File('lib/pages/trip_detail_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('hasDistinctPoints'));
      expect(content, contains('initialCameraFit: hasDistinctPoints'));
    });

    test('BackgroundLocationService specifies timeLimit on getCurrentPosition', () {
      final file = File('lib/services/background_location_service.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('timeLimit: Duration(seconds: 4)'));
    });
  });
}
