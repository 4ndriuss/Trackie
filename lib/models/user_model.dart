// File: lib/models/user_model.dart
// Model data yang merepresentasikan pengguna (User) beserta informasi langganannya.
import 'subscription_model.dart';

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

  /// Paket langganan pengguna ('free' atau 'premium')
  final String plan;

  /// Status langganan ('active', 'expired', atau 'canceled')
  final String subscriptionStatus;

  /// Tanggal berakhir/perpanjangan langganan Premium (opsional)
  final DateTime? expiresAt;

  /// Apakah pengguna sudah pernah melihat halaman pemilihan paket Subscription
  final bool hasSeenSubscriptionPage;

  /// Konstruktor utama untuk [UserModel]
  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.vehicle = '',
    this.phone,
    this.birthDate,
    this.photoUrl,
    this.plan = 'free',
    this.subscriptionStatus = 'active',
    this.expiresAt,
    this.hasSeenSubscriptionPage = false,
    DateTime? createdAt,
    DateTime? joinedAt,
  }) : createdAt = createdAt ?? joinedAt ?? DateTime.now();

  /// Alias getter untuk [createdAt] guna menjaga kompatibilitas kode
  DateTime get joinedAt => createdAt;

  /// Mengonversi field subscription pada [UserModel] menjadi [SubscriptionInfo]
  SubscriptionInfo get subscriptionInfo => SubscriptionInfo(
        plan: SubscriptionPlan.fromString(plan),
        status: SubscriptionStatus.fromString(subscriptionStatus),
        expiresAt: expiresAt,
        autoRenew: plan == 'premium' && subscriptionStatus == 'active',
        hasSeenSubscriptionPage: hasSeenSubscriptionPage,
      );

  /// Membuat instance [UserModel] dari generic [Map]
  factory UserModel.fromMap(Map<String, dynamic> map, [String? uid]) {
    final parsedUid = uid ??
        map['id'] as String? ??
        map['uid'] as String? ??
        '';

    final rawExpires = map['subscription_expires_at'] ?? map['expiresAt'];
    final parsedExpires = rawExpires != null ? _parseDateTime(rawExpires) : null;

    final rawHasSeen =
        map['has_seen_subscription_page'] ?? map['hasSeenSubscriptionPage'];

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
      plan: (map['plan'] as String?) ?? 'free',
      subscriptionStatus: (map['subscription_status'] ??
              map['subscriptionStatus']) as String? ??
          'active',
      expiresAt: parsedExpires,
      hasSeenSubscriptionPage: rawHasSeen is bool ? rawHasSeen : false,
      createdAt: _parseDateTime(
        map['created_at'] ?? map['createdAt'] ?? map['joinedAt'],
      ),
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
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'avatar_url': photoUrl,
      'photoUrl': photoUrl,
      'plan': plan,
      'subscription_status': subscriptionStatus,
      'subscriptionStatus': subscriptionStatus,
      'subscription_expires_at': expiresAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'has_seen_subscription_page': hasSeenSubscriptionPage,
      'hasSeenSubscriptionPage': hasSeenSubscriptionPage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Alias untuk toMap
  Map<String, dynamic> toFirestore() => toMap();

  /// Map untuk tabel `public.profiles` di Supabase
  Map<String, dynamic> toSupabase({bool includeSubscriptionFields = false}) {
    final base = <String, dynamic>{
      'id': uid,
      'name': name,
      'email': email,
      'vehicle': vehicle,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'avatar_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
    if (includeSubscriptionFields) {
      base['plan'] = plan;
      base['subscription_status'] = subscriptionStatus;
      base['subscription_expires_at'] = expiresAt?.toIso8601String();
      base['has_seen_subscription_page'] = hasSeenSubscriptionPage;
    }
    return base;
  }

  /// Membuat salinan objek dengan modifikasi atribut tertentu
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? vehicle,
    String? phone,
    DateTime? birthDate,
    String? photoUrl,
    String? plan,
    String? subscriptionStatus,
    DateTime? expiresAt,
    bool? hasSeenSubscriptionPage,
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
      plan: plan ?? this.plan,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      expiresAt: expiresAt ?? this.expiresAt,
      hasSeenSubscriptionPage:
          hasSeenSubscriptionPage ?? this.hasSeenSubscriptionPage,
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
      try {
        final seconds = (value as dynamic).seconds as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } catch (_) {}
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, vehicle: $vehicle, plan: $plan, subscriptionStatus: $subscriptionStatus, expiresAt: $expiresAt, hasSeenSubscriptionPage: $hasSeenSubscriptionPage)';
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
        other.plan == plan &&
        other.subscriptionStatus == subscriptionStatus &&
        other.expiresAt == expiresAt &&
        other.hasSeenSubscriptionPage == hasSeenSubscriptionPage &&
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
        plan.hashCode ^
        subscriptionStatus.hashCode ^
        expiresAt.hashCode ^
        hasSeenSubscriptionPage.hashCode ^
        createdAt.hashCode;
  }
}
