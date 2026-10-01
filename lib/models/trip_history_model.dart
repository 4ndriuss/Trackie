import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model data yang merepresentasikan riwayat perjalanan di koleksi Firestore `trip_history`.
class TripHistoryModel {
  /// Unique Identifier riwayat perjalanan / dokumen Firestore
  final String id;

  /// Nama grup perjalanan
  final String groupName;

  /// Jenis/tipe kendaraan ('motor', 'mobil', 'sepeda')
  final String groupType;

  /// Total jarak tempuh perjalanan dalam kilometer (km)
  final double distanceKm;

  /// Durasi perjalanan dalam format string (misal: "1j 45m" atau "01:45:00")
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

  /// Alias getter untuk [journalNote] guna kompatibilitas update
  String? get note => journalNote;

  /// Menghasilkan representasi titik rute dalam bentuk [LatLng] untuk Google Maps
  List<LatLng> get routePoints => routePath
      .map((point) => LatLng(point['lat'] ?? 0.0, point['lng'] ?? 0.0))
      .toList();

  /// Membuat instance [TripHistoryModel] dari Firestore [DocumentSnapshot]
  factory TripHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TripHistoryModel.fromMap(data, doc.id);
  }

  /// Membuat instance [TripHistoryModel] dari generic [Map]
  factory TripHistoryModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return TripHistoryModel(
      id: id ?? map['id'] as String? ?? '',
      groupName: map['groupName'] as String? ?? '',
      groupType: map['groupType'] as String? ?? 'motor',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      duration: map['duration'] as String? ?? '',
      routePath: _parseRoutePath(map['routePath']),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
      startedAt: _parseDateTime(map['startedAt']),
      endedAt: _parseDateTime(map['endedAt']),
      journalNote: map['journalNote'] as String? ?? map['note'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
    );
  }

  /// Mengonversi instance ke bentuk Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'groupName': groupName,
      'groupType': groupType,
      'distanceKm': distanceKm,
      'duration': duration,
      'routePath': routePath,
      'memberCount': memberCount,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'journalNote': journalNote,
      'note': journalNote,
      'rating': rating,
    };
  }

  /// Alias untuk [toFirestore] guna kompatibilitas umum
  Map<String, dynamic> toMap() => toFirestore();

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
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
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
