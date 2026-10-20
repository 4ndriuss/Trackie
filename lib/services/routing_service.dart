// File: routing_service.dart
// Layanan pencarian lokasi (Nominatim OpenStreetMap) dan perhitungan rute jalan raya
// beserta petunjuk arah belokan (OSRM - Open Source Routing Machine).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'haversine_utils.dart';

/// Menyimpan data titik tujuan grup (nama lokasi + koordinat).
class DestinationTarget {
  final String name;
  final LatLng point;

  const DestinationTarget({
    required this.name,
    required this.point,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': point.latitude,
        'lng': point.longitude,
      };

  factory DestinationTarget.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim() ?? 'Tujuan';
    final lat = (map['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (map['lng'] as num?)?.toDouble() ?? 0.0;
    return DestinationTarget(
      name: name.isEmpty ? 'Tujuan' : name,
      point: LatLng(lat, lng),
    );
  }
}

/// Hasil saran pencarian tempat dari Nominatim OpenStreetMap.
class PlaceSuggestion {
  final String title;
  final String displayName;
  final LatLng point;

  const PlaceSuggestion({
    required this.title,
    required this.displayName,
    required this.point,
  });
}

/// Informasi satu langkah belokan (turn-by-turn step) dari OSRM.
class RouteStepInfo {
  final String instruction;
  final String maneuverType;
  final String? maneuverModifier;
  final double distanceMeters;
  final LatLng location;

  const RouteStepInfo({
    required this.instruction,
    required this.maneuverType,
    this.maneuverModifier,
    required this.distanceMeters,
    required this.location,
  });
}

/// Hasil rute lengkap dari posisi pengguna ke titik tujuan.
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStepInfo> steps;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  /// Format jarak total (misal: "450 m" atau "12.4 km").
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Format estimasi durasi perjalanan (misal: "18 mnt" atau "1 j 25 mnt").
  String get formattedDuration {
    final totalMinutes = (durationSeconds / 60).round().clamp(1, 99999);
    if (totalMinutes < 60) {
      return '$totalMinutes mnt';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '$hours j $mins mnt' : '$hours jam';
  }

  /// Estimasi jam tiba (misal: "19:45").
  String get formattedEtaClock {
    final arrival =
        DateTime.now().add(Duration(seconds: durationSeconds.round()));
    final hh = arrival.hour.toString().padLeft(2, '0');
    final mm = arrival.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Menentukan langkah navigasi berikutnya berdasarkan posisi pengguna saat ini.
  RouteStepInfo? nextStepFor(LatLng currentPos) {
    if (steps.isEmpty) return null;
    if (steps.length == 1) return steps.first;

    int closestIndex = 0;
    double minDist = double.infinity;

    for (int i = 0; i < steps.length; i++) {
      final d = HaversineUtils.distanceInMeters(
        currentPos.latitude,
        currentPos.longitude,
        steps[i].location.latitude,
        steps[i].location.longitude,
      );
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }

    if (minDist < 35 && closestIndex + 1 < steps.length) {
      return steps[closestIndex + 1];
    }
    if (steps[closestIndex].maneuverType == 'depart' &&
        closestIndex + 1 < steps.length) {
      return steps[closestIndex + 1];
    }
    return steps[closestIndex];
  }
}

class RoutingService {
  static Map<String, String> get _headers => {
        if (!kIsWeb) 'User-Agent': 'TrackieApp/1.0 (com.example.trackie)',
        'Accept': 'application/json',
      };

  /// Mengemas nama tujuan dan koordinat ke dalam satu string untuk disimpan di kolom `destination`
  /// tanpa perlu mengubah skema database. Format: `Nama Tempat||lat,lng`
  static String encodeDestination(String name, LatLng? point) {
    final cleanName = cleanDestinationName(name);
    if (point == null) return cleanName;
    return '$cleanName||${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
  }

  /// Mengambil nama tujuan bersih tanpa koordinat tersemat.
  static String cleanDestinationName(String raw) {
    final idx = raw.indexOf('||');
    if (idx == -1) return raw.trim();
    return raw.substring(0, idx).trim();
  }

  /// Mengekstrak [DestinationTarget] jika string tujuan memiliki koordinat tersemat.
  static DestinationTarget? tryParseEmbeddedDestination(String raw) {
    final idx = raw.indexOf('||');
    if (idx == -1) return null;
    final name = raw.substring(0, idx).trim();
    final coordPart = raw.substring(idx + 2).trim();
    final parts = coordPart.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return DestinationTarget(
      name: name.isEmpty ? 'Tujuan' : name,
      point: LatLng(lat, lng),
    );
  }

  /// Mencari daftar lokasi berdasarkan kata kunci menggunakan Nominatim OpenStreetMap.
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '6',
        'addressdetails': '1',
        'accept-language': 'id,en',
      });

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      final results = <PlaceSuggestion>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        final displayName = (item['display_name'] as String?)?.trim() ?? '';
        if (lat == null || lon == null || displayName.isEmpty) continue;

        final rawName = (item['name'] as String?)?.trim() ?? '';
        final title = rawName.isNotEmpty
            ? rawName
            : displayName.split(',').first.trim();

        results.add(
          PlaceSuggestion(
            title: title,
            displayName: displayName,
            point: LatLng(lat, lon),
          ),
        );
      }
      return results;
    } catch (e) {
      debugPrint('Error searching places: $e');
      return const [];
    }
  }

  /// Mengambil nama tempat dari titik koordinat (Reverse Geocoding) saat Host tap di peta.
  Future<String> reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'jsonv2',
        'accept-language': 'id,en',
      });

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final name = (decoded['name'] as String?)?.trim() ?? '';
          if (name.isNotEmpty) return name;

          final displayName = (decoded['display_name'] as String?)?.trim() ?? '';
          if (displayName.isNotEmpty) {
            final segments = displayName.split(',').map((s) => s.trim()).toList();
            return segments.take(2).join(', ');
          }
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
    return 'Titik Peta (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
  }

  /// Menghitung rute jalan raya dari `origin` ke `destination` menggunakan OSRM.
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    String vehicleType = 'motor',
  }) async {
    final profile =
        vehicleType.toLowerCase().contains('sepeda') ? 'bike' : 'driving';
    final coordinatesPath =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';

    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/$profile/$coordinatesPath',
        {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
        },
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map &&
            data['code'] == 'Ok' &&
            data['routes'] is List &&
            (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List).first as Map;
          final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final rawDuration = (route['duration'] as num?)?.toDouble() ?? 0.0;
          final duration = vehicleType.toLowerCase() == 'motor'
              ? rawDuration * 0.9
              : rawDuration;

          final points = <LatLng>[];
          final geometry = route['geometry'];
          if (geometry is Map && geometry['coordinates'] is List) {
            for (final coord in geometry['coordinates'] as List) {
              if (coord is List && coord.length >= 2) {
                final lon = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lon));
              }
            }
          }

          final steps = <RouteStepInfo>[];
          if (route['legs'] is List && (route['legs'] as List).isNotEmpty) {
            final firstLeg = (route['legs'] as List).first;
            if (firstLeg is Map && firstLeg['steps'] is List) {
              for (final s in firstLeg['steps'] as List) {
                if (s is! Map) continue;
                final maneuver = s['maneuver'] as Map?;
                if (maneuver == null) continue;

                final type = (maneuver['type'] as String?) ?? 'continue';
                final modifier = maneuver['modifier'] as String?;
                final roadName = (s['name'] as String?)?.trim() ?? '';
                final stepDist = (s['distance'] as num?)?.toDouble() ?? 0.0;

                LatLng stepLoc = destination;
                final locList = maneuver['location'];
                if (locList is List && locList.length >= 2) {
                  stepLoc = LatLng(
                    (locList[1] as num).toDouble(),
                    (locList[0] as num).toDouble(),
                  );
                }

                steps.add(
                  RouteStepInfo(
                    instruction: _buildIndonesianInstruction(
                      type: type,
                      modifier: modifier,
                      roadName: roadName,
                    ),
                    maneuverType: type,
                    maneuverModifier: modifier,
                    distanceMeters: stepDist,
                    location: stepLoc,
                  ),
                );
              }
            }
          }

          if (points.isNotEmpty) {
            return RouteResult(
              points: points,
              distanceMeters: distance,
              durationSeconds: duration,
              steps: steps,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching OSRM route: $e');
    }

    // Fallback garis lurus jika internet lambat / OSRM sedang tidak merespons
    final directDist = HaversineUtils.distanceInMeters(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final estSeconds = (directDist / 11.1).clamp(60.0, 86400.0);
    return RouteResult(
      points: [origin, destination],
      distanceMeters: directDist,
      durationSeconds: estSeconds,
      steps: [
        RouteStepInfo(
          instruction: 'Menuju titik tujuan',
          maneuverType: 'continue',
          distanceMeters: directDist,
          location: destination,
        ),
      ],
    );
  }

  static String _buildIndonesianInstruction({
    required String type,
    String? modifier,
    required String roadName,
  }) {
    final targetRoad = roadName.isNotEmpty ? ' ke $roadName' : '';
    final onRoad = roadName.isNotEmpty ? ' di $roadName' : '';

    switch (type) {
      case 'depart':
        return 'Mulai perjalanan$onRoad';
      case 'arrive':
        return 'Tiba di tujuan';
      case 'roundabout':
      case 'rotary':
        return 'Masuk bundaran$targetRoad';
      case 'exit roundabout':
      case 'exit rotary':
        return 'Keluar bundaran$targetRoad';
      case 'merge':
        return 'Bergabung ke jalur$targetRoad';
      case 'on ramp':
      case 'off ramp':
        return 'Ambil jalur keluar$targetRoad';
      case 'fork':
        if (modifier != null && modifier.contains('left')) {
          return 'Ambil percabangan kiri$targetRoad';
        } else if (modifier != null && modifier.contains('right')) {
          return 'Ambil percabangan kanan$targetRoad';
        }
        return 'Ikuti percabangan jalan$targetRoad';
      default:
        break;
    }

    switch (modifier) {
      case 'uturn':
        return 'Putar balik$onRoad';
      case 'sharp left':
        return 'Belok tajam ke kiri$targetRoad';
      case 'left':
        return 'Belok kiri$targetRoad';
      case 'slight left':
        return 'Serong kiri$targetRoad';
      case 'sharp right':
        return 'Belok tajam ke kanan$targetRoad';
      case 'right':
        return 'Belok kanan$targetRoad';
      case 'slight right':
        return 'Serong kanan$targetRoad';
      case 'straight':
      default:
        return roadName.isNotEmpty
            ? 'Lurus terus di $roadName'
            : 'Lurus terus ikuti jalan';
    }
  }
}
