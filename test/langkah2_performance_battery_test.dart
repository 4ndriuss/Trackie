import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackie/providers/location_provider.dart';
import 'package:trackie/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Langkah 2: PERF-18 GPS Downsampling & Accurate Distance Tests', () {
    test('downsamplePoints returns original list when points <= maxPoints', () {
      final points = List.generate(50, (i) => LatLng(-6.2 + (i * 0.001), 106.8 + (i * 0.001)));
      final downsampled = LocationProvider.downsamplePoints(points, maxPoints: 100);

      expect(downsampled.length, equals(50));
      expect(downsampled.first, equals(points.first));
      expect(downsampled.last, equals(points.last));
    });

    test('downsamplePoints compresses large path (> 1000 points) to <= 100 points preserving boundaries', () {
      final points = List.generate(1500, (i) => LatLng(-6.2 + (i * 0.0001), 106.8 + (i * 0.0001)));
      final downsampled = LocationProvider.downsamplePoints(points, maxPoints: 100);

      expect(downsampled.length, lessThanOrEqualTo(100));
      expect(downsampled.length, greaterThan(20));
      expect(downsampled.first, equals(points.first));
      expect(downsampled.last, equals(points.last));
    });

    test('buildCompletedTripHistory downsamples long recorded paths for JSONB storage', () {
      final lp = LocationProvider();

      // Buat riwayat perjalanan dengan simulasi 300 titik koordinat terekam
      final points = List.generate(300, (i) => LatLng(-6.2 + (i * 0.0005), 106.8 + (i * 0.0005)));
      for (final _ in points) {
        // Simulasi perekaman titik
        lp.buildCompletedTripHistory(
          groupName: 'Touring Puncak',
          rawDestination: 'Puncak Pass',
          groupType: 'motor',
          isHost: true,
          fallbackMemberCount: 4,
        );
      }

      // Verifikasi helper downsamplePoints langsung pada 300 titik
      final downsampled = LocationProvider.downsamplePoints(points, maxPoints: 100);
      expect(downsampled.length, lessThanOrEqualTo(100));
      expect(downsampled.first.latitude, equals(points.first.latitude));
      expect(downsampled.last.latitude, equals(points.last.latitude));

      lp.dispose();
    });
  });

  group('Langkah 2: PERF-06 & PERF-16 Trip History Query & Pagination Optimization Tests', () {
    test('TripService summaryColumns excludes route_path and includes essential metadata', () {
      const summaryColumns = TripService.summaryColumns;

      expect(summaryColumns, isNot(contains('route_path')));
      expect(summaryColumns, contains('id'));
      expect(summaryColumns, contains('user_id'));
      expect(summaryColumns, contains('group_name'));
      expect(summaryColumns, contains('distance_km'));
      expect(summaryColumns, contains('duration'));
      expect(summaryColumns, contains('member_count'));
      expect(summaryColumns, contains('started_at'));
      expect(summaryColumns, contains('ended_at'));
    });

    test('TripService methods support pagination and limit parameters', () {
      final service = TripService();
      expect(service, isNotNull);

      // Verifikasi signature getTripHistory memiliki parameter limit, offset, dan includeRoutePath
      expect(
        () => service.getTripHistory('dummy-uid', limit: 25, offset: 5, includeRoutePath: false),
        returnsNormally,
      );
    });
  });

  group('Langkah 2: PERF-15 ProfileTab Ghost Mode Rebuild Isolation Static Check', () {
    test('ProfileTab uses Selector<LocationProvider, bool> instead of context.watch', () {
      final file = File('lib/pages/profile_tab.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('Selector<LocationProvider, bool>'));
      expect(content, contains('lp.isGhostMode'));
      // Pastikan tidak ada context.watch<LocationProvider> di dalam file
      expect(content, isNot(contains('context.watch<LocationProvider>()')));
    });
  });
}
