// File: test/widget_test.dart
// Pengujian widget dan unit testing logika inti Trackie.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackie/models/subscription_model.dart';
import 'package:trackie/services/haversine_utils.dart';
import 'package:trackie/pages/onboarding_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasSeenSubscriptionOnboarding': true,
    });
  });

  group('Widget Tests', () {
    testWidgets('OnboardingPage renders title and buttons correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingPage(),
        ),
      );
      await tester.pump();

      expect(find.text('Your Adventure Starts Here'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  });

  group('HaversineUtils Unit Tests', () {
    test('Calculates zero distance for identical points', () {
      final dist = HaversineUtils.distanceInMeters(-6.2, 106.8, -6.2, 106.8);
      expect(dist, 0.0);
    });

    test('Calculates realistic distance between Jakarta and Bandung (~115-150 km)', () {
      // Jakarta: -6.2088, 106.8456
      // Bandung: -6.9175, 107.6191
      final distMeters = HaversineUtils.distanceInMeters(
        -6.2088,
        106.8456,
        -6.9175,
        107.6191,
      );
      expect(distMeters, greaterThan(110000));
      expect(distMeters, lessThan(160000));
    });

    test('Formats distance string correctly for meters and kilometers', () {
      expect(HaversineUtils.formatDistance(500), '500 m');
      expect(HaversineUtils.formatDistance(1500), '1.5 km');
      expect(HaversineUtils.formatDistance(12345), '12.3 km');
    });
  });

  group('Subscription & PlanLimits Unit Tests', () {
    test('Free plan limits to freeMaxGroups (2 groups)', () {
      final max = PlanLimits.maxGroupsFor(
        plan: SubscriptionPlan.free,
        status: SubscriptionStatus.active,
      );
      expect(max, PlanLimits.freeMaxGroups);
      expect(max, 2);
    });

    test('Active Premium plan limits to premiumMaxGroups (20 groups)', () {
      final max = PlanLimits.maxGroupsFor(
        plan: SubscriptionPlan.premium,
        status: SubscriptionStatus.active,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(max, PlanLimits.premiumMaxGroups);
      expect(max, 20);
    });

    test('Expired Premium plan falls back to freeMaxGroups (2 groups)', () {
      final max = PlanLimits.maxGroupsFor(
        plan: SubscriptionPlan.premium,
        status: SubscriptionStatus.expired,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(max, PlanLimits.freeMaxGroups);
    });

    test('SubscriptionInfo model properties and active check', () {
      final premiumInfo = SubscriptionInfo(
        plan: SubscriptionPlan.premium,
        status: SubscriptionStatus.active,
        billingCycle: BillingCycle.monthly,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      expect(premiumInfo.isPremiumActive, isTrue);
      expect(premiumInfo.maxGroups, 20);
      expect(premiumInfo.planDisplayName, 'Premium');

      const freeInfo = SubscriptionInfo();
      expect(freeInfo.isPremiumActive, isFalse);
      expect(freeInfo.maxGroups, 2);
      expect(freeInfo.planDisplayName, 'Free');
    });
  });
}
