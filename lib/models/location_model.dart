/// Model data lokasi anggota grup untuk node Realtime Database `active_locations`.
class MemberLocation {
  /// UID anggota grup
  final String uid;

  /// Nama tampilan anggota
  final String name;

  /// Latitude koordinat posisi anggota
  final double lat;

  /// Longitude koordinat posisi anggota
  final double lng;

  /// Unix timestamp dalam milidetik saat lokasi diperbarui
  final int timestamp;

  /// Status koneksi atau kondisi ('online', 'offline', 'sos')
  final String status;

  /// Konstruktor utama untuk [MemberLocation]
  MemberLocation({
    required this.uid,
    required this.name,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.status,
  });

  /// Alias getter untuk kompatibilitas properti latitude
  double get latitude => lat;

  /// Alias getter untuk kompatibilitas properti longitude
  double get longitude => lng;

  /// Status apakah anggota sedang aktif / online
  bool get isOnline => status == 'online';

  /// Status apakah anggota sedang offline
  bool get isOffline => status == 'offline';

  /// Status apakah anggota sedang mengirim sinyal darurat (SOS)
  bool get isSos => status == 'sos';

  /// Tanggal & waktu berdasarkan timestamp milidetik
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// Membuat instance [MemberLocation] dari Map Realtime Database dengan UID terpisah
  factory MemberLocation.fromRtdb(Map<dynamic, dynamic> map, String uid) {
    return MemberLocation.fromMap(map, uid);
  }

  /// Membuat instance [MemberLocation] dari generic Map, mendukung variasi key 'lat'/'latitude' dan 'lng'/'longitude'
  factory MemberLocation.fromMap(Map<dynamic, dynamic> map, [String? uid]) {
    final rawLat = map['lat'] ?? map['latitude'];
    final rawLng = map['lng'] ?? map['longitude'];
    final rawTimestamp = map['timestamp'];

    return MemberLocation(
      uid: uid ?? map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      lat: (rawLat as num?)?.toDouble() ?? 0.0,
      lng: (rawLng as num?)?.toDouble() ?? 0.0,
      timestamp: (rawTimestamp as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'online',
    );
  }

  /// Mengonversi instance ke Map untuk disimpan di node Realtime Database
  Map<String, dynamic> toRtdb() {
    return {
      'uid': uid,
      'name': name,
      'lat': lat,
      'lng': lng,
      'latitude': lat,
      'longitude': lng,
      'timestamp': timestamp,
      'status': status,
    };
  }

  /// Alias untuk [toRtdb] guna kompatibilitas umum
  Map<String, dynamic> toMap() => toRtdb();

  /// Membuat salinan objek dengan modifikasi atribut tertentu
  MemberLocation copyWith({
    String? uid,
    String? name,
    double? lat,
    double? lng,
    int? timestamp,
    String? status,
  }) {
    return MemberLocation(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'MemberLocation(uid: $uid, name: $name, lat: $lat, lng: $lng, timestamp: $timestamp, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemberLocation &&
        other.uid == uid &&
        other.name == name &&
        other.lat == lat &&
        other.lng == lng &&
        other.timestamp == timestamp &&
        other.status == status;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        lat.hashCode ^
        lng.hashCode ^
        timestamp.hashCode ^
        status.hashCode;
  }
}
