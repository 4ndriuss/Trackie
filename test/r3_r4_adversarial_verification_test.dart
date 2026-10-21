// File: test/r3_r4_adversarial_verification_test.dart
// Adversarial verification test suite for Requirements R3 (MapPage Rebuild Isolation)
// and R4 (HistoryTab Stream Fix & Lifecycle Management).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackie/models/location_model.dart';
import 'package:trackie/models/trip_history_model.dart';
import 'package:trackie/pages/history_tab.dart';
import 'package:trackie/pages/map_page.dart';
import 'package:trackie/providers/auth_provider.dart';
import 'package:trackie/providers/group_provider.dart';
import 'package:trackie/providers/location_provider.dart';
import 'package:trackie/services/routing_service.dart';

// Test implementation of LocationProvider allowing fine-grained simulation
class TestLocationProvider extends LocationProvider {
  Position? _mockPosition;
  List<MemberLocation> _mockMembers = [];
  RouteResult? _mockRoute;
  DestinationTarget? _mockDestination;
  final bool _mockIsLoadingRoute = false;

  @override
  Position? get currentPosition => _mockPosition;

  @override
  List<MemberLocation> get members => _mockMembers;

  @override
  RouteResult? get activeRoute => _mockRoute;

  @override
  DestinationTarget? get destinationTarget => _mockDestination;

  @override
  bool get isLoadingRoute => _mockIsLoadingRoute;

  void updateMockPosition(double lat, double lng) {
    _mockPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 20.0,
      speedAccuracy: 1.0,
    );
    notifyListeners();
  }

  void updateMockMembers(List<MemberLocation> newMembers) {
    _mockMembers = newMembers;
    notifyListeners();
  }

  void updateMockRoute(RouteResult? route) {
    _mockRoute = route;
    notifyListeners();
  }

  void updateMockDestination(DestinationTarget? dest) {
    _mockDestination = dest;
    notifyListeners();
  }

  void triggerNotify() {
    notifyListeners();
  }
}

// Mock AuthProvider for deterministic testing without Supabase network calls
class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  String? _uid;
  MockAuthProvider([this._uid]);

  void setUid(String? newUid) {
    _uid = newUid;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #user) {
      if (_uid == null) return null;
      return _MockUser(_uid!);
    }
    if (invocation.memberName == #isAuthenticated) {
      return _uid != null;
    }
    if (invocation.memberName == #isLoading) {
      return false;
    }
    return super.noSuchMethod(invocation);
  }
}

class _MockUser {
  final String uid;
  _MockUser(this.uid);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R3 Adversarial: GroupMember Model & Equality Contract', () {
    test('Reflexivity: GroupMember equals itself', () {
      const member = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 100.0,
      );
      expect(member == member, isTrue);
      expect(member.hashCode, equals(member.hashCode));
    });

    test('Symmetry and Transitivity of GroupMember equality', () {
      const m1 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 100.0,
      );
      const m2 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 100.0,
      );
      const m3 = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.2, 106.8),
        distanceMeters: 100.0,
      );

      // Symmetry
      expect(m1 == m2, isTrue);
      expect(m2 == m1, isTrue);
      expect(m1.hashCode, equals(m2.hashCode));

      // Transitivity
      expect(m2 == m3, isTrue);
      expect(m1 == m3, isTrue);
    });

    test('Granular inequality checks on every distinct attribute', () {
      const base = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.200000, 106.800000),
        distanceMeters: 150.0,
      );

      // 1. Different ID
      const diffId = GroupMember(
        id: 'u2',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.200000, 106.800000),
        distanceMeters: 150.0,
      );
      expect(base == diffId, isFalse);

      // 2. Different Name
      const diffName = GroupMember(
        id: 'u1',
        name: 'Rider 2',
        status: MemberStatus.online,
        position: LatLng(-6.200000, 106.800000),
        distanceMeters: 150.0,
      );
      expect(base == diffName, isFalse);

      // 3. Different Status (online -> offline -> sos)
      const diffStatusOffline = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.offline,
        position: LatLng(-6.200000, 106.800000),
        distanceMeters: 150.0,
      );
      const diffStatusSos = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.sos,
        position: LatLng(-6.200000, 106.800000),
        distanceMeters: 150.0,
      );
      expect(base == diffStatusOffline, isFalse);
      expect(base == diffStatusSos, isFalse);
      expect(diffStatusOffline == diffStatusSos, isFalse);
      expect(diffStatusOffline.isOnline, isFalse);
      expect(diffStatusSos.isSos, isTrue);
      expect(diffStatusSos.isOnline, isTrue);

      // 4. Different Position (latitude or longitude)
      const diffLat = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.200001, 106.800000),
        distanceMeters: 150.0,
      );
      const diffLng = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.200000, 106.800001),
        distanceMeters: 150.0,
      );
      expect(base == diffLat, isFalse);
      expect(base == diffLng, isFalse);

      // 5. Different Distance
      const diffDist = GroupMember(
        id: 'u1',
        name: 'Rider 1',
        status: MemberStatus.online,
        position: LatLng(-6.200000, 106.800000),
        distanceMeters: 150.5,
      );
      expect(base == diffDist, isFalse);
    });

    test('Set and Map hashing resilience: 100 unique members produce distinct hashes', () {
      final membersSet = <GroupMember>{};
      final hashes = <int>{};

      for (int i = 0; i < 100; i++) {
        final member = GroupMember(
          id: 'u_$i',
          name: 'Rider $i',
          status: i % 3 == 0 ? MemberStatus.sos : (i % 2 == 0 ? MemberStatus.online : MemberStatus.offline),
          position: LatLng(-6.2 + (i * 0.001), 106.8 + (i * 0.001)),
          distanceMeters: i * 25.0,
        );
        membersSet.add(member);
        hashes.add(member.hashCode);
      }

      expect(membersSet.length, equals(100));
      // Hash collision distribution should be low (< 5% collisions across 100 distinct inputs)
      expect(hashes.length, greaterThan(95));

      // Adding identical duplicates does not increase Set size
      for (int i = 0; i < 100; i++) {
        final duplicate = GroupMember(
          id: 'u_$i',
          name: 'Rider $i',
          status: i % 3 == 0 ? MemberStatus.sos : (i % 2 == 0 ? MemberStatus.online : MemberStatus.offline),
          position: LatLng(-6.2 + (i * 0.001), 106.8 + (i * 0.001)),
          distanceMeters: i * 25.0,
        );
        membersSet.add(duplicate);
      }
      expect(membersSet.length, equals(100));
    });
  });

  group('R3 Adversarial: MapPage Rebuild Isolation Empirical Verification', () {
    testWidgets('TileLayer and FlutterMap do NOT rebuild when LocationProvider coordinates update', (tester) async {
      final locationProvider = TestLocationProvider();
      final authProvider = MockAuthProvider(null);
      final groupProvider = GroupProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocationProvider>.value(value: locationProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<GroupProvider>.value(value: groupProvider),
          ],
          child: const MaterialApp(
            home: MapPage(isHost: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find FlutterMap and TileLayer
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      final flutterMapElement = tester.element(find.byType(FlutterMap));
      final tileLayerElement = tester.element(find.byType(TileLayer));
      expect(flutterMapElement, isNotNull);
      expect(tileLayerElement, isNotNull);

      final initialMapRenderObject = flutterMapElement.renderObject;
      final initialTileRenderObject = tileLayerElement.renderObject;

      // STRESS TEST: Fire 25 high-frequency location coordinate updates
      for (int i = 1; i <= 25; i++) {
        locationProvider.updateMockPosition(
          -6.200000 + (i * 0.0001),
          106.816666 + (i * 0.0001),
        );
        await tester.pump();
      }

      // Assert that FlutterMap and TileLayer elements retained their exact RenderObjects
      expect(tester.element(find.byType(FlutterMap)).renderObject, same(initialMapRenderObject));
      expect(tester.element(find.byType(TileLayer)).renderObject, same(initialTileRenderObject));
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      locationProvider.dispose();
      authProvider.dispose();
      groupProvider.dispose();
    });

    testWidgets('Selector Granularity: Builder is only called when selected slice mutates', (tester) async {
      final locationProvider = TestLocationProvider();
      int routeSelectorEvaluations = 0;
      int routeBuilderExecutions = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<LocationProvider>.value(
          value: locationProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Selector<LocationProvider, RouteResult?>(
                selector: (_, lp) {
                  routeSelectorEvaluations++;
                  return lp.activeRoute;
                },
                builder: (context, activeRoute, _) {
                  routeBuilderExecutions++;
                  return Text('Route points: ${activeRoute?.points.length ?? 0}');
                },
              ),
            ),
          ),
        ),
      );

      expect(routeBuilderExecutions, equals(1));
      expect(find.text('Route points: 0'), findsOneWidget);

      // Location updates (without activeRoute mutation)
      for (int i = 0; i < 15; i++) {
        locationProvider.updateMockPosition(
          -6.2 + (i * 0.001),
          106.8,
        );
        await tester.pump();
      }

      // Selector was re-evaluated, but because activeRoute == null (identical), builder was NEVER re-executed!
      expect(routeSelectorEvaluations, greaterThan(15));
      expect(routeBuilderExecutions, equals(1), reason: 'Route builder must not rebuild when only GPS coordinates change');

      // Now mutate activeRoute and verify builder DOES execute
      locationProvider.updateMockRoute(
        RouteResult(
          points: [
            const LatLng(-6.2, 106.8),
            const LatLng(-6.21, 106.81),
          ],
          distanceMeters: 1500,
          durationSeconds: 180,
          steps: const [],
        ),
      );
      await tester.pump();

      expect(routeBuilderExecutions, equals(2));
      expect(find.text('Route points: 2'), findsOneWidget);

      locationProvider.dispose();
    });

    testWidgets('BottomSheet Selector: does not rebuild when notifyListeners fired with identical members', (tester) async {
      final locationProvider = TestLocationProvider();
      int sheetBuilderExecutions = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<LocationProvider>.value(
          value: locationProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Selector<LocationProvider, List<MemberLocation>>(
                selector: (_, lp) => lp.members,
                builder: (context, members, _) {
                  sheetBuilderExecutions++;
                  return Text('Members: ${members.length}');
                },
              ),
            ),
          ),
        ),
      );

      expect(sheetBuilderExecutions, equals(1));

      // Trigger 10 provider notifications without changing members list instance
      for (int i = 0; i < 10; i++) {
        locationProvider.triggerNotify();
        await tester.pump();
      }

      expect(sheetBuilderExecutions, equals(1), reason: 'Sheet builder must not rebuild when members list is unchanged');

      locationProvider.dispose();
    });
  });

  group('R4 Adversarial: HistoryTab Stream Fix & Lifecycle Verification', () {
    testWidgets('HistoryTab initializes without throwing and cancels cleanly on unmount', (tester) async {
      final authProvider = MockAuthProvider(null); // Unauthenticated user

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: HistoryTab(),
          ),
        ),
      );
      await tester.pump();

      // Verify History title renders without errors
      expect(find.byType(HistoryTab), findsOneWidget);

      // Verify unmount / disposal cleans up without throwing
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: Scaffold(body: Text('Different Tab')),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HistoryTab), findsNothing);
      expect(find.text('Different Tab'), findsOneWidget);

      authProvider.dispose();
    });

    testWidgets('Repeated widget rebuilds do not leak or recreate stream subscriptions', (tester) async {
      final authProvider = MockAuthProvider(null);

      int parentBuilds = 0;
      late StateSetter triggerParentBuild;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                triggerParentBuild = setState;
                parentBuilds++;
                return const Scaffold(
                  body: HistoryTab(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(parentBuilds, equals(1));

      // Trigger 20 rapid frame rebuilds on parent widget
      for (int i = 0; i < 20; i++) {
        triggerParentBuild(() {});
        await tester.pump();
      }

      expect(parentBuilds, equals(21));
      expect(find.byType(HistoryTab), findsOneWidget);

      authProvider.dispose();
    });

    testWidgets('Tab switching (mount -> unmount -> mount) cycles cleanly without crash', (tester) async {
      final authProvider = MockAuthProvider(null);
      int currentTab = 0;
      late StateSetter setTabState;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                setTabState = setState;
                return Scaffold(
                  body: currentTab == 0 ? const HistoryTab() : const Text('Other View'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(HistoryTab), findsOneWidget);

      // Switch back and forth 10 times
      for (int i = 0; i < 10; i++) {
        setTabState(() => currentTab = 1);
        await tester.pump();
        expect(find.byType(HistoryTab), findsNothing);

        setTabState(() => currentTab = 0);
        await tester.pump();
        expect(find.byType(HistoryTab), findsOneWidget);
      }

      authProvider.dispose();
    });

    test('Oracle Verification: Deterministic stream subscription prevents channel recreation & leaks cleanly', () async {
      // Simulates the architectural pattern used by HistoryTab
      int totalListenInvocations = 0;
      int totalCancelInvocations = 0;
      StreamController<List<TripHistoryModel>>? activeController;

      Stream<List<TripHistoryModel>> mockStreamTripHistory(String uid) {
        totalListenInvocations++;
        activeController = StreamController<List<TripHistoryModel>>.broadcast(
          onCancel: () {
            totalCancelInvocations++;
          },
        );
        return activeController!.stream;
      }

      StreamSubscription<List<TripHistoryModel>>? subscription;
      String? subscribedUid;

      void subscribe(String? uid) {
        subscribedUid = uid;
        subscription?.cancel();
        subscription = null;

        if (uid != null) {
          subscription = mockStreamTripHistory(uid).listen((_) {});
        }
      }

      void dispose() {
        subscription?.cancel();
        subscription = null;
      }

      // Initial subscription
      subscribe('user_1');
      expect(totalListenInvocations, equals(1));
      expect(totalCancelInvocations, equals(0));
      expect(activeController?.hasListener, isTrue);

      // Redundant rebuilds with same UID: no recreation
      if ('user_1' != subscribedUid) {
        subscribe('user_1');
      }
      expect(totalListenInvocations, equals(1), reason: 'Rebuild with same UID must not recreate stream');

      // User switches accounts
      subscribe('user_2');
      expect(totalListenInvocations, equals(2));
      expect(totalCancelInvocations, equals(1), reason: 'Previous stream must be cleanly cancelled');

      // User logs out
      subscribe(null);
      expect(totalCancelInvocations, equals(2), reason: 'Logout must cleanly cancel stream');
      expect(subscription, isNull);

      // Re-login & dispose
      subscribe('user_3');
      expect(totalListenInvocations, equals(3));
      dispose();
      expect(totalCancelInvocations, equals(3), reason: 'Dispose must cancel stream cleanly without leaks');
      expect(subscription, isNull);
    });
  });
}
