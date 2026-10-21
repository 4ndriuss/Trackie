// File: test/phase2_optimization_test.dart
// Unit tests for Phase 2 optimizations: GroupMember equality, lifecycle handling, and safety guards.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackie/pages/map_page.dart';
import 'package:trackie/providers/location_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroupMember Model & Equality Unit Tests', () {
    test('GroupMember with identical attributes are equal and share hashCode', () {
      const member1 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 50.0,
      );

      const member2 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 50.0,
      );

      expect(member1, equals(member2));
      expect(member1.hashCode, equals(member2.hashCode));
      expect(member1.isOnline, isTrue);
      expect(member1.isSos, isFalse);
    });

    test('GroupMember inequality when position or status differs', () {
      const member1 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 50.0,
      );

      const member2 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.sos,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 50.0,
      );

      const member3 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.205, 106.805),
        distanceMeters: 50.0,
      );

      expect(member1, isNot(equals(member2)));
      expect(member1, isNot(equals(member3)));
      expect(member2.isSos, isTrue);
    });
  });

  group('LocationProvider Lifecycle Unit Tests', () {
    test('LocationProvider initializes with WidgetsBindingObserver safely', () {
      final lp = LocationProvider();
      expect(lp.isTracking, isFalse);
      expect(lp.members, isEmpty);

      // Verify no-op when not tracking
      lp.handleAppLifecycleState(AppLifecycleState.paused);
      expect(lp.isTracking, isFalse);

      lp.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(lp.isTracking, isFalse);

      lp.dispose();
    });
  });
}
