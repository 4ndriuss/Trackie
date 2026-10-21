import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Langkah 3: SEC-04 & SEC-11 AndroidManifest Native Hardening Tests', () {
    test('AndroidManifest.xml explicitly defines allowBackup false and exported false for services', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();

      // SEC-04: Mencegah ekstraksi database & shared preferences via ADB backup
      expect(content, contains('android:allowBackup="false"'));

      // SEC-11: Proteksi Background Service dari IPC akses liar eksternal
      expect(content, contains('id.flutter.flutter_background_service.BackgroundService'));
      expect(content, contains('android:exported="false"'));
    });
  });

  group('Langkah 3: SEC-03 & SEC-08 Gradle Build & ProGuard Obfuscation Tests', () {
    test('build.gradle.kts configures release signing config and key.properties loading', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();

      // SEC-03: Pemuatan key.properties dan konfigurasi signingConfigs release
      expect(content, contains('key.properties'));
      expect(content, contains('signingConfigs'));
      expect(content, contains('create("release")'));

      // SEC-08: Application ID resmi produksi (bukan default template)
      expect(content, contains('applicationId = "com.trackie.app"'));

      // SEC-08: R8 Minifikasi, Shrinking, dan Obfuscation
      expect(content, contains('isMinifyEnabled = true'));
      expect(content, contains('isShrinkResources = true'));
      expect(content, contains('proguard-rules.pro'));
    });

    test('proguard-rules.pro exists and protects essential flutter & plugin classes', () {
      final rulesFile = File('android/app/proguard-rules.pro');
      expect(rulesFile.existsSync(), isTrue, reason: 'File proguard-rules.pro harus tersedia');

      final content = rulesFile.readAsStringSync();
      expect(content, contains('io.flutter'));
      expect(content, contains('flutter_background_service'));
      expect(content, contains('androidx.security.crypto'));
    });

    test('key.properties.example exists to document release keystore signing setup', () {
      final exampleFile = File('android/key.properties.example');
      expect(exampleFile.existsSync(), isTrue);

      final content = exampleFile.readAsStringSync();
      expect(content, contains('storePassword'));
      expect(content, contains('keyAlias'));
    });
  });

  group('Langkah 3: Package Name Consistency Across Native & Dart Files', () {
    test('OSM user agents and native configs use uniform com.trackie.app identifier', () {
      final mapPage = File('lib/pages/map_page.dart').readAsStringSync();
      expect(mapPage, contains("userAgentPackageName: 'com.trackie.app'"));

      final detailPage = File('lib/pages/trip_detail_page.dart').readAsStringSync();
      expect(detailPage, contains("userAgentPackageName: 'com.trackie.app'"));

      final routingService = File('lib/services/routing_service.dart').readAsStringSync();
      expect(routingService, contains('TrackieApp/1.0 (com.trackie.app)'));

      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = com.trackie.app;'));

      final appInfo = File('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync();
      expect(appInfo, contains('PRODUCT_BUNDLE_IDENTIFIER = com.trackie.app'));

      final cmake = File('linux/CMakeLists.txt').readAsStringSync();
      expect(cmake, contains('set(APPLICATION_ID "com.trackie.app")'));
    });
  });
}
