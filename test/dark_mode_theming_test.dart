import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trackie/theme/app_theme.dart';
import 'package:trackie/widgets/social_button.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ARCH-04: Dark Mode Theming & Design System Contract Tests', () {
    test('AppTheme.lightTheme and darkTheme preserve brand primary color', () {
      expect(AppTheme.lightTheme.primaryColor, equals(AppTheme.primary));
      expect(AppTheme.darkTheme.primaryColor, equals(AppTheme.primary));
      expect(AppTheme.lightTheme.colorScheme.primary, equals(AppTheme.primary));
      expect(AppTheme.darkTheme.colorScheme.primary, equals(AppTheme.primary));
    });

    test('AppTheme provides dedicated cardColor and scaffoldBackgroundColor for darkTheme', () {
      expect(AppTheme.darkTheme.brightness, equals(Brightness.dark));
      expect(AppTheme.darkTheme.cardColor, equals(const Color(0xFF2D3035)));
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, equals(AppTheme.textDark));
      expect(AppTheme.darkTheme.colorScheme.surface, equals(const Color(0xFF2D3035)));
      expect(AppTheme.darkTheme.colorScheme.onSurface, equals(AppTheme.neutral));
    });

    test('AppTheme provides clean white surface tokens for lightTheme', () {
      expect(AppTheme.lightTheme.brightness, equals(Brightness.light));
      expect(AppTheme.lightTheme.cardColor, equals(AppTheme.neutral));
      expect(AppTheme.lightTheme.colorScheme.surface, equals(AppTheme.neutral));
      expect(AppTheme.lightTheme.colorScheme.onSurface, equals(AppTheme.textDark));
    });

    testWidgets('SocialButton adapts cleanly to Light and Dark Mode contexts', (tester) async {
      // Test Light Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SocialButton(
              text: 'Lanjutkan dengan Google',
              icon: const Icon(Icons.g_mobiledata),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Lanjutkan dengan Google'), findsOneWidget);

      // Test Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SocialButton(
              text: 'Lanjutkan dengan Google',
              icon: const Icon(Icons.g_mobiledata),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Lanjutkan dengan Google'), findsOneWidget);
    });
  });

  group('DEP-07: iOS OAuth URL Scheme Contract Test', () {
    test('Info.plist contains CFBundleURLTypes for com.trackie.app OAuth redirect', () {
      final infoPlistFile = File('ios/Runner/Info.plist');
      expect(infoPlistFile.existsSync(), isTrue, reason: 'ios/Runner/Info.plist must exist');

      final content = infoPlistFile.readAsStringSync();
      expect(content.contains('CFBundleURLTypes'), isTrue,
          reason: 'Info.plist must register CFBundleURLTypes for OAuth redirect handling');
      expect(content.contains('com.trackie.app'), isTrue,
          reason: 'CFBundleURLSchemes must include com.trackie.app bundle URL scheme');
    });
  });
}
