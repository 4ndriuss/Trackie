import 'package:latlong2/latlong.dart';

/// Model data yang merepresentasikan riwayat perjalanan.
class TripHistoryModel {
  /// Unique Identifier riwayat perjalanan
  final String id;

  /// Nama grup perjalanan (dapat memuat metadata `groupName||destination||role`)
  final String groupName;

  /// Jenis/tipe kendaraan ('motor', 'mobil', 'sepeda')
  final String groupType;

  /// Total jarak tempuh perjalanan dalam kilometer (km)
  final double distanceKm;

  /// Durasi perjalanan dalam format string (misal: "1j 45m" atau "45m")
  final String duration;

  /// Daftar koordinat rute perjalanan berupa list pasangan latitude dan longitude
  final List<Map<String, double>> routePath;

  /// Jumlah anggota yang berpartisipasi dalam perjalanan
  final int memberCount;

  /// Waktu perjalanan dimulai
  final DateTime startedAt;

  /// Waktu perjalanan selesai/diakhiri
  final DateTime endedAt;

  /// Catatan jurnal perjalanan dari pengguna (opsional)
  final String? journalNote;

  /// Nilai penilaian / rating kepuasan perjalanan (opsional, skala 1.0 - 5.0)
  final double? rating;

  /// Konstruktor utama untuk [TripHistoryModel]
  TripHistoryModel({
    required this.id,
    required this.groupName,
    required this.groupType,
    required this.distanceKm,
    required this.duration,
    required this.routePath,
    required this.memberCount,
    required this.startedAt,
    required this.endedAt,
    this.journalNote,
    this.rating,
  });

  /// Mengemas nama grup, tujuan, dan peran pengguna ke dalam satu string `group_name`
  /// agar tersimpan utuh di tabel `public.trip_history` tanpa ubah skema SQL.
  static String encodeGroupMeta({
    required String groupName,
    required String destination,
    required String role,
  }) {
    final cleanGroup = groupName.replaceAll('||', ' ').trim();
    final cleanDest = destination.replaceAll('||', ' ').trim();
    final cleanRole = role.replaceAll('||', ' ').trim();
    return '$cleanGroup||$cleanDest||$cleanRole';
  }

  /// Nama grup bersih untuk ditampilkan di UI.
  String get displayGroupName {
    final parts = groupName.split('||');
    return parts.first.trim().isNotEmpty ? parts.first.trim() : 'Perjalanan';
  }

  /// Nama tujuan perjalanan yang diekstrak dari metadata.
  String get destinationName {
    final parts = groupName.split('||');
    if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
      return parts[1].trim();
    }
    return displayGroupName;
  }

  /// Peran pengguna dalam perjalanan ('Host' atau 'Member').
  String get role {
    final parts = groupName.split('||');
    if (parts.length >= 3 && parts[2].trim().isNotEmpty) {
      return parts[2].trim();
    }
    return 'Host';
  }

  /// Kecepatan rata-rata dalam km/jam.
  double get avgSpeedKmh {
    final seconds = endedAt.difference(startedAt).inSeconds;
    if (seconds <= 0 || distanceKm <= 0) return 0.0;
    final hours = seconds / 3600.0;
    final speed = distanceKm / hours;
    // Batasi nilai wajar jika durasi pengetesan sangat singkat
    return speed > 120.0 ? 40.0 : double.parse(speed.toStringAsFixed(1));
  }

  /// Alias getter untuk [journalNote] guna kompatibilitas update
  String? get note => journalNote;

  /// Menghasilkan representasi titik rute dalam bentuk [LatLng]
  List<LatLng> get routePoints => routePath
      .map((point) => LatLng(point['lat'] ?? 0.0, point['lng'] ?? 0.0))
      .toList();

  /// Membuat instance [TripHistoryModel] dari generic [Map]
  factory TripHistoryModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return TripHistoryModel(
      id: id ?? map['id'] as String? ?? '',
      groupName:
          map['group_name'] as String? ?? map['groupName'] as String? ?? '',
      groupType:
          map['group_type'] as String? ?? map['groupType'] as String? ?? 'motor',
      distanceKm:
          (map['distance_km'] ?? map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      duration: map['duration'] as String? ?? '',
      routePath: _parseRoutePath(map['route_path'] ?? map['routePath']),
      memberCount:
          (map['member_count'] ?? map['memberCount'] as num?)?.toInt() ?? 1,
      startedAt: _parseDateTime(map['started_at'] ?? map['startedAt']),
      endedAt: _parseDateTime(map['ended_at'] ?? map['endedAt']),
      journalNote: map['journal_note'] as String? ??
          map['journalNote'] as String? ??
          map['note'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
    );
  }

  /// Mengonversi instance ke bentuk Map
  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'group_name': groupName,
      'groupName': groupName,
      'group_type': groupType,
      'groupType': groupType,
      'distance_km': distanceKm,
      'distanceKm': distanceKm,
      'duration': duration,
      'route_path': routePath,
      'routePath': routePath,
      'member_count': memberCount,
      'memberCount': memberCount,
      'started_at': startedAt.toIso8601String(),
      'startedAt': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'journal_note': journalNote,
      'journalNote': journalNote,
      'note': journalNote,
      'rating': rating,
    };
  }

  /// Alias untuk toMap
  Map<String, dynamic> toFirestore() => toMap();
  Map<String, dynamic> toSupabase() => {
        if (id.isNotEmpty) 'id': id,
        'group_name': groupName,
        'group_type': groupType,
        'distance_km': distanceKm,
        'duration': duration,
        'route_path': routePath,
        'member_count': memberCount,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'journal_note': journalNote,
        'rating': rating,
      };

  /// Membuat salinan objek dengan perubahan nilai parsial
  TripHistoryModel copyWith({
    String? id,
    String? groupName,
    String? groupType,
    double? distanceKm,
    String? duration,
    List<Map<String, double>>? routePath,
    int? memberCount,
    DateTime? startedAt,
    DateTime? endedAt,
    String? journalNote,
    double? rating,
  }) {
    return TripHistoryModel(
      id: id ?? this.id,
      groupName: groupName ?? this.groupName,
      groupType: groupType ?? this.groupType,
      distanceKm: distanceKm ?? this.distanceKm,
      duration: duration ?? this.duration,
      routePath: routePath ?? List<Map<String, double>>.from(this.routePath),
      memberCount: memberCount ?? this.memberCount,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      journalNote: journalNote ?? this.journalNote,
      rating: rating ?? this.rating,
    );
  }

  /// Helper untuk mem-parsing daftar koordinat secara aman
  static List<Map<String, double>> _parseRoutePath(dynamic rawList) {
    if (rawList is! List) return [];
    return rawList.map((item) {
      if (item is Map) {
        final lat =
            (item['lat'] ?? item['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng =
            (item['lng'] ?? item['longitude'] as num?)?.toDouble() ?? 0.0;
        return <String, double>{'lat': lat, 'lng': lng};
      }
      return <String, double>{'lat': 0.0, 'lng': 0.0};
    }).toList();
  }

  /// Helper untuk mem-parsing format DateTime
  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value != null && value.toString().contains('Timestamp')) {
      try {
        final seconds = (value as dynamic).seconds as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } catch (_) {}
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'TripHistoryModel(id: $id, groupName: $groupName, groupType: $groupType, distanceKm: $distanceKm, duration: $duration, routePath: ${routePath.length} points, memberCount: $memberCount, startedAt: $startedAt, endedAt: $endedAt, journalNote: $journalNote, rating: $rating)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripHistoryModel &&
        other.id == id &&
        other.groupName == groupName &&
        other.groupType == groupType &&
        other.distanceKm == distanceKm &&
        other.duration == duration &&
        other.memberCount == memberCount &&
        other.startedAt == startedAt &&
        other.endedAt == endedAt &&
        other.journalNote == journalNote &&
        other.rating == rating;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        groupName.hashCode ^
        groupType.hashCode ^
        distanceKm.hashCode ^
        duration.hashCode ^
        memberCount.hashCode ^
        startedAt.hashCode ^
        endedAt.hashCode ^
        journalNote.hashCode ^
        rating.hashCode;
  }
}
