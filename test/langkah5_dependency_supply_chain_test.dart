import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackie/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Langkah 5 Supply Chain & Dependency Contract Tests', () {
    test('DEP-04 & DEP-05: pubspec.yaml does not contain dead dependencies (uuid, cupertino_icons)', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final content = pubspecFile.readAsStringSync();

      // Verify dead direct dependencies are removed
      expect(content.contains(RegExp(r'^\s*uuid:\s*\^', multiLine: true)), isFalse,
          reason: 'uuid should be removed as a direct dependency');
      expect(content.contains(RegExp(r'^\s*cupertino_icons:\s*\^', multiLine: true)), isFalse,
          reason: 'cupertino_icons should be removed as a direct dependency');
    });

    test('DEP-03: flutter_facebook_auth removed from direct dependencies to eliminate binary bloat', () {
      final pubspecFile = File('pubspec.yaml');
      final content = pubspecFile.readAsStringSync();

      expect(content.contains('flutter_facebook_auth:'), isFalse,
          reason: 'flutter_facebook_auth should be removed until official Meta App ID is provisioned');
    });

    test('DEP-01 & DEP-06: flexible versioning for google_sign_in and permission_handler', () {
      final pubspecFile = File('pubspec.yaml');
      final content = pubspecFile.readAsStringSync();

      // google_sign_in should use caret constraint ^6.
      expect(content.contains(RegExp(r'google_sign_in:\s*\^6\.')), isTrue,
          reason: 'google_sign_in should allow security patch updates');

      // permission_handler is pinned to ^11.4.0
      expect(content.contains('permission_handler: ^11.4.0'), isTrue);
    });

    test('DEP-07: android/app/build.gradle.kts uses modernized desugar_jdk_libs 2.1.4', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content.contains('desugar_jdk_libs:2.1.4'), isTrue,
          reason: 'desugar_jdk_libs must be 2.1.4 for modern Java 11/17 desugaring');
      expect(content.contains('desugar_jdk_libs:2.0.4'), isFalse,
          reason: 'legacy desugar_jdk_libs 2.0.4 should be replaced');
    });

    test('DEP-03 Code Integrity: AuthService.signInWithFacebook gracefully rejects without crashing', () async {
      final authService = AuthService();
      expect(
        () => authService.signInWithFacebook(),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Facebook Login belum dikonfigurasi'),
        )),
      );
    });
  });
}
