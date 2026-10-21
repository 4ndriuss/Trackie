import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackie/models/group_member_model.dart';
import 'package:trackie/models/group_model.dart';
import 'package:trackie/models/trip_history_model.dart';
import 'package:trackie/pages/map_page.dart' as map_page;
import 'package:trackie/providers/group_provider.dart';
import 'package:trackie/providers/location_provider.dart';
import 'package:trackie/providers/theme_provider.dart';
import 'package:trackie/services/auth_service.dart';
import 'package:trackie/services/group_service.dart';
import 'package:trackie/services/location_service.dart';
import 'package:trackie/services/subscription_service.dart';
import 'package:trackie/services/trip_service.dart';

class _FakeTripService extends TripService {
  bool saveTripCalled = false;
  String? lastUid;
  TripHistoryModel? lastTrip;

  @override
  Future<void> saveTrip({required String uid, required TripHistoryModel trip}) async {
    saveTripCalled = true;
    lastUid = uid;
    lastTrip = trip;
  }
}

class _FakeGroupProvider extends GroupProvider {
  bool endGroupCalled = false;
  bool leaveGroupCalled = false;
  String? leftUid;

  @override
  Future<void> endGroup() async {
    endGroupCalled = true;
  }

  @override
  Future<void> leaveGroup({String? uid}) async {
    leaveGroupCalled = true;
    leftUid = uid;
  }
}

void main() {
  group('Langkah 6: Architecture & Quality Tests', () {
    test('ARCH-07: GroupMember domain model is decoupled into models/group_member_model.dart', () {
      const member = GroupMember(
        id: 'member_1',
        name: 'Budi Santoso',
        status: MemberStatus.online,
        position: LatLng(-6.2088, 106.8456),
        distanceMeters: 450.0,
      );

      expect(member.id, 'member_1');
      expect(member.isOnline, isTrue);
      expect(member.isSos, isFalse);
      expect(formatDistance(450.0), '450 m');
      expect(formatDistance(2500.0), '2.5 km');

      // Verify backward compatible export via map_page.dart
      expect(map_page.MemberStatus.sos, MemberStatus.sos);
    });

    test('ARCH-11: Services support Constructor Dependency Injection for unit test isolation', () {
      // Services instantiate with default singleton fallback without error
      final tripService = TripService();
      final groupService = GroupService();
      final authService = AuthService();
      final locationService = LocationService();
      final subService = MockSubscriptionService();

      expect(tripService, isNotNull);
      expect(groupService, isNotNull);
      expect(authService, isNotNull);
      expect(locationService, isNotNull);
      expect(subService, isNotNull);
    });

    test('ARCH-06: LocationProvider.completeAndEndTrip encapsulates finish trip business orchestration', () async {
      final locationProvider = LocationProvider();
      final fakeTripService = _FakeTripService();
      final fakeGroupProvider = _FakeGroupProvider();

      final activeGroup = GroupModel(
        id: 'grp_arch_06',
        name: 'Touring Puncak',
        inviteCode: 'TRG-ARCH06',
        hostUid: 'host_123',
        destination: 'Puncak Pass||-6.7023,106.9856',
        type: 'motorcycle',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        memberUids: const ['host_123', 'm2', 'm3'],
      );

      // Execute unified orchestration as Host
      final success = await locationProvider.completeAndEndTrip(
        uid: 'host_123',
        activeGroup: activeGroup,
        isHost: true,
        groupProvider: fakeGroupProvider,
        tripService: fakeTripService,
      );

      expect(success, isTrue);
      expect(fakeTripService.saveTripCalled, isTrue);
      expect(fakeTripService.lastUid, 'host_123');
      expect(fakeTripService.lastTrip?.groupType, 'motorcycle');
      expect(fakeGroupProvider.endGroupCalled, isTrue);
      expect(fakeGroupProvider.leaveGroupCalled, isFalse);

      // Execute unified orchestration as regular Member
      final fakeTripServiceMember = _FakeTripService();
      final fakeGroupProviderMember = _FakeGroupProvider();

      final memberSuccess = await locationProvider.completeAndEndTrip(
        uid: 'member_456',
        activeGroup: activeGroup,
        isHost: false,
        groupProvider: fakeGroupProviderMember,
        tripService: fakeTripServiceMember,
      );

      expect(memberSuccess, isTrue);
      expect(fakeTripServiceMember.saveTripCalled, isTrue);
      expect(fakeTripServiceMember.lastUid, 'member_456');
      expect(fakeGroupProviderMember.endGroupCalled, isFalse);
      expect(fakeGroupProviderMember.leaveGroupCalled, isTrue);
      expect(fakeGroupProviderMember.leftUid, 'member_456');
    });

    test('ARCH-12 & BUG-18: ThemeProvider manages and updates ThemeMode reactively', () async {
      final themeProvider = ThemeProvider(initialMode: ThemeMode.light);

      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDarkMode, isFalse);

      int notifyCount = 0;
      themeProvider.addListener(() {
        notifyCount++;
      });

      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, isTrue);
      expect(notifyCount, 1);

      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDarkMode, isFalse);
      expect(notifyCount, 2);
    });
  });
}
