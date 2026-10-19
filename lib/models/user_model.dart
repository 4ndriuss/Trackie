/// Model data yang merepresentasikan pengguna (User).
class UserModel {
  /// Unique Identifier dari Autentikasi
  final String uid;

  /// Nama lengkap pengguna
  final String name;

  /// Alamat email pengguna
  final String email;

  /// Jenis atau nomor kendaraan pengguna (opsional, default string kosong)
  final String vehicle;

  /// Nomor telepon dengan kode negara
  final String? phone;

  /// Tanggal lahir
  final DateTime? birthDate;

  /// Tanggal dan waktu akun dibuat
  final DateTime createdAt;

  /// URL foto profil pengguna (opsional)
  final String? photoUrl;

  /// Konstruktor utama untuk [UserModel]
  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.vehicle = '',
    this.phone,
    this.birthDate,
    this.photoUrl,
    DateTime? createdAt,
    DateTime? joinedAt,
  }) : createdAt = createdAt ?? joinedAt ?? DateTime.now();

  /// Alias getter untuk [createdAt] guna menjaga kompatibilitas kode
  DateTime get joinedAt => createdAt;

  /// Membuat instance [UserModel] dari generic [Map]
  factory UserModel.fromMap(Map<String, dynamic> map, [String? uid]) {
    final parsedUid = uid ??
        map['id'] as String? ??
        map['uid'] as String? ??
        '';

    return UserModel(
      uid: parsedUid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      vehicle: map['vehicle'] as String? ?? '',
      phone: map['phone'] as String?,
      birthDate: (map['birth_date'] ?? map['birthDate']) != null
          ? _parseDateTime(map['birth_date'] ?? map['birthDate'])
          : null,
      photoUrl: (map['avatar_url'] ?? map['photoUrl']) as String?,
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt'] ?? map['joinedAt']),
    );
  }

  /// Mengonversi instance [UserModel] ke dalam bentuk Map
  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'uid': uid,
      'name': name,
      'email': email,
      'vehicle': vehicle,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String(),
      'avatar_url': photoUrl,
      'photoUrl': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Alias untuk toMap
  Map<String, dynamic> toFirestore() => toMap();
  Map<String, dynamic> toSupabase() => {
        'id': uid,
        'name': name,
        'email': email,
        'vehicle': vehicle,
        'phone': phone,
        'birth_date': birthDate?.toIso8601String(),
        'avatar_url': photoUrl,
        'created_at': createdAt.toIso8601String(),
      };

  /// Membuat salinan objek dengan modifikasi atribut tertentu
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? vehicle,
    String? phone,
    DateTime? birthDate,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      vehicle: vehicle ?? this.vehicle,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Helper untuk mem-parsing berbagai format DateTime / Timestamp
  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value != null && value.toString().contains('Timestamp')) {
      // Menangani bila masih ada sisa snapshot lama
      try {
        final seconds = (value as dynamic).seconds as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } catch (_) {}
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, vehicle: $vehicle, phone: $phone, birthDate: $birthDate, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.name == name &&
        other.email == email &&
        other.vehicle == vehicle &&
        other.phone == phone &&
        other.birthDate == birthDate &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        email.hashCode ^
        vehicle.hashCode ^
        phone.hashCode ^
        birthDate.hashCode ^
        createdAt.hashCode;
  }
}
