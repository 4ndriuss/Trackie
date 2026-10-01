// File: location_service.dart
// Service untuk mengelola lokasi real-time anggota grup
// menggunakan Firebase Realtime Database.
import 'package:firebase_database/firebase_database.dart';
import '../models/location_model.dart';

/// [LocationService] menyediakan operasi broadcast dan stream lokasi
/// pada node 'active_locations/{groupId}/{uid}' di Firebase RTDB.
class LocationService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Broadcast lokasi pengguna ke node RTDB grup.
  /// Path: active_locations/{groupId}/{uid}
  Future<void> updateLocation({
    required String groupId,
    required String uid,
    required String name,
    required double lat,
    required double lng,
    String status = 'online',
  }) async {
    final location = MemberLocation(
      uid: uid,
      name: name,
      lat: lat,
      lng: lng,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      status: status,
    );

    await _rtdb
        .ref('active_locations/$groupId/$uid')
        .set(location.toRtdb());
  }

  /// Stream lokasi semua anggota dalam satu grup.
  /// Mengembalikan Stream<List<MemberLocation>>.
  Stream<List<MemberLocation>> streamGroupLocations(String groupId) {
    return _rtdb.ref('active_locations/$groupId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <MemberLocation>[];

      final map = data as Map<dynamic, dynamic>;
      return map.entries.map((entry) {
        final uid = entry.key as String;
        final value = entry.value as Map<dynamic, dynamic>;
        return MemberLocation.fromRtdb(value, uid);
      }).toList();
    });
  }

  /// Set status user menjadi 'offline' saat keluar dari grup.
  Future<void> setOffline({
    required String groupId,
    required String uid,
  }) async {
    await _rtdb.ref('active_locations/$groupId/$uid').update({
      'status': 'offline',
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Hapus data lokasi user dari RTDB.
  Future<void> removeLocation({
    required String groupId,
    required String uid,
  }) async {
    await _rtdb.ref('active_locations/$groupId/$uid').remove();
  }

  /// Bersihkan seluruh data lokasi grup dari RTDB (saat grup berakhir).
  Future<void> cleanupGroupLocations(String groupId) async {
    await _rtdb.ref('active_locations/$groupId').remove();
  }

  /// Aktifkan sinyal SOS untuk user.
  Future<void> triggerSOS({
    required String groupId,
    required String uid,
  }) async {
    await _rtdb.ref('active_locations/$groupId/$uid').update({
      'status': 'sos',
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Batalkan sinyal SOS (kembali ke 'online').
  Future<void> cancelSOS({
    required String groupId,
    required String uid,
  }) async {
    await _rtdb.ref('active_locations/$groupId/$uid').update({
      'status': 'online',
      'timestamp': ServerValue.timestamp,
    });
  }
}
