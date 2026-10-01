import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data yang merepresentasikan grup perjalanan di koleksi Firestore `groups`.
class GroupModel {
  /// Unique Identifier dari grup/dokumen Firestore
  final String id;

  /// Nama grup perjalanan
  final String name;

  /// Tipe kendaraan grup ('motor', 'mobil', 'sepeda')
  final String type;

  /// Kode unik undangan (format TRG-XXX)
  final String inviteCode;

  /// UID pengguna pembuat / host grup
  final String hostUid;

  /// Daftar UID anggota yang terdaftar di grup
  final List<String> memberUids;

  /// Status grup ('active' atau 'ended')
  final String status;

  /// Tanggal dan waktu grup dibuat
  final DateTime createdAt;

  /// Tanggal dan waktu grup diakhiri (opsional, null jika masih aktif)
  final DateTime? endedAt;

  /// Konstruktor utama untuk [GroupModel]
  GroupModel({
    required this.id,
    required this.name,
    required this.type,
    required this.inviteCode,
    required this.hostUid,
    required this.memberUids,
    required this.status,
    required this.createdAt,
    this.endedAt,
  });

  /// Status apakah grup masih aktif
  bool get isActive => status == 'active';

  /// Status apakah grup telah selesai / diakhiri
  bool get isEnded => status == 'ended';

  /// Cek apakah pengguna tertentu merupakan host
  bool isHost(String uid) => hostUid == uid;

  /// Cek apakah pengguna tertentu merupakan anggota grup
  bool isMember(String uid) => memberUids.contains(uid);

  /// Jumlah total anggota grup saat ini
  int get memberCount => memberUids.length;

  /// Membuat instance [GroupModel] dari Firestore [DocumentSnapshot]
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GroupModel.fromMap(data, doc.id);
  }

  /// Membuat instance [GroupModel] dari generic [Map]
  factory GroupModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final rawMembers = map['memberUids'] as List<dynamic>?;
    final List<String> members = rawMembers != null
        ? List<String>.from(rawMembers.map((e) => e.toString()))
        : <String>[];

    return GroupModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'motor',
      inviteCode: map['inviteCode'] as String? ?? '',
      hostUid: map['hostUid'] as String? ?? '',
      memberUids: members,
      status: map['status'] as String? ?? 'active',
      createdAt: _parseDateTime(map['createdAt']),
      endedAt: _parseNullableDateTime(map['endedAt']),
    );
  }

  /// Mengonversi instance [GroupModel] ke dalam bentuk Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'inviteCode': inviteCode,
      'hostUid': hostUid,
      'memberUids': memberUids,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  /// Alias untuk [toFirestore] guna kompatibilitas fungsi umum
  Map<String, dynamic> toMap() => toFirestore();

  /// Membuat salinan objek [GroupModel] dengan perubahan parsial
  GroupModel copyWith({
    String? id,
    String? name,
    String? type,
    String? inviteCode,
    String? hostUid,
    List<String>? memberUids,
    String? status,
    DateTime? createdAt,
    DateTime? endedAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      inviteCode: inviteCode ?? this.inviteCode,
      hostUid: hostUid ?? this.hostUid,
      memberUids: memberUids ?? List<String>.from(this.memberUids),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  /// Helper untuk mem-parsing format DateTime wajib
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

  /// Helper untuk mem-parsing format DateTime yang opsional / nullable
  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value);
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  @override
  String toString() {
    return 'GroupModel(id: $id, name: $name, type: $type, inviteCode: $inviteCode, hostUid: $hostUid, memberUids: $memberUids, status: $status, createdAt: $createdAt, endedAt: $endedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupModel &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.inviteCode == inviteCode &&
        other.hostUid == hostUid &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.endedAt == endedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        type.hashCode ^
        inviteCode.hashCode ^
        hostUid.hashCode ^
        status.hashCode ^
        createdAt.hashCode ^
        endedAt.hashCode;
  }
}
