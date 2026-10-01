import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data yang merepresentasikan pengguna (User) di koleksi Firestore `users`.
class UserModel {
  /// Unique Identifier dari Firebase Authentication
  final String uid;

  /// Nama lengkap pengguna
  final String name;

  /// Alamat email pengguna
  final String email;

  /// Jenis atau nomor kendaraan pengguna (opsional, default string kosong)
  final String vehicle;

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
    this.photoUrl,
    DateTime? createdAt,
    DateTime? joinedAt,
  }) : createdAt = createdAt ?? joinedAt ?? DateTime.now();

  /// Alias getter untuk [createdAt] guna menjaga kompatibilitas kode
  DateTime get joinedAt => createdAt;

  /// Membuat instance [UserModel] dari Firestore [DocumentSnapshot]
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  /// Membuat instance [UserModel] dari generic [Map]
  factory UserModel.fromMap(Map<String, dynamic> map, [String? uid]) {
    return UserModel(
      uid: uid ?? map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      vehicle: map['vehicle'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      createdAt: _parseDateTime(map['createdAt'] ?? map['joinedAt']),
    );
  }

  /// Mengonversi instance [UserModel] ke dalam bentuk Map untuk disimpan di Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'vehicle': vehicle,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'joinedAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Alias untuk [toFirestore] untuk kemudahan integrasi dengan service
  Map<String, dynamic> toMap() => toFirestore();

  /// Membuat salinan objek dengan modifikasi atribut tertentu
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? vehicle,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      vehicle: vehicle ?? this.vehicle,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Helper untuk mem-parsing berbagai format DateTime / Timestamp
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
    return 'UserModel(uid: $uid, name: $name, email: $email, vehicle: $vehicle, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.name == name &&
        other.email == email &&
        other.vehicle == vehicle &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        email.hashCode ^
        vehicle.hashCode ^
        createdAt.hashCode;
  }
}
