// File: group_service.dart
// Service untuk mengelola grup/perjalanan: membuat, bergabung, keluar, dan mengakhiri.
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/group_model.dart';

/// [GroupService] menyediakan operasi CRUD untuk koleksi 'groups' di Firestore
/// dan pembersihan data lokasi di Realtime Database.
class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Membuat kode undangan unik dengan format TRG-XXX.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(3, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    return 'TRG-$code';
  }

  /// Membuat grup baru dan mengembalikan [GroupModel].
  Future<GroupModel> createGroup({
    required String name,
    required String type,
    required String hostUid,
  }) async {
    final docRef = _firestore.collection('groups').doc();
    final inviteCode = _generateInviteCode();

    final group = GroupModel(
      id: docRef.id,
      name: name,
      type: type,
      inviteCode: inviteCode,
      hostUid: hostUid,
      memberUids: [hostUid],
      status: 'active',
      createdAt: DateTime.now(),
    );

    await docRef.set(group.toFirestore());
    return group;
  }

  /// Bergabung ke grup yang sudah ada menggunakan kode undangan.
  /// Mengembalikan [GroupModel] jika berhasil, null jika kode tidak ditemukan.
  Future<GroupModel?> joinGroup({
    required String inviteCode,
    required String uid,
  }) async {
    final querySnapshot = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    final doc = querySnapshot.docs.first;
    final group = GroupModel.fromFirestore(doc);

    if (!group.memberUids.contains(uid)) {
      await _firestore.collection('groups').doc(group.id).update({
        'memberUids': FieldValue.arrayUnion([uid]),
      });
    }

    // Kembalikan group terbaru dengan uid sudah ditambahkan
    return GroupModel.fromFirestore(
      await _firestore.collection('groups').doc(group.id).get(),
    );
  }

  /// Keluar dari grup. Jika anggota terakhir, grup otomatis diakhiri.
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    final doc = await docRef.get();

    if (doc.exists) {
      final group = GroupModel.fromFirestore(doc);

      if (group.memberUids.length <= 1) {
        // Anggota terakhir keluar, akhiri grup
        await endGroup(groupId);
      } else {
        await docRef.update({
          'memberUids': FieldValue.arrayRemove([uid]),
        });
        // Hapus data lokasi user dari RTDB
        await _rtdb.ref('active_locations/$groupId/$uid').remove();
      }
    }
  }

  /// Mengakhiri grup: set status 'ended' dan bersihkan data lokasi di RTDB.
  Future<void> endGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'status': 'ended',
      'endedAt': Timestamp.now(),
    });
    await _rtdb.ref('active_locations/$groupId').remove();
  }

  /// Mengambil data grup berdasarkan ID.
  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (doc.exists) {
      return GroupModel.fromFirestore(doc);
    }
    return null;
  }

  /// Mencari grup aktif yang diikuti oleh user tertentu.
  Future<GroupModel?> getActiveGroupForUser(String uid) async {
    final querySnapshot = await _firestore
        .collection('groups')
        .where('memberUids', arrayContains: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return GroupModel.fromFirestore(querySnapshot.docs.first);
    }
    return null;
  }

  /// Stream data grup secara real-time.
  Stream<GroupModel?> streamGroup(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return GroupModel.fromFirestore(doc);
      }
      return null;
    });
  }
}
