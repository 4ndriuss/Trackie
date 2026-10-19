// File: location_service.dart
// Service untuk mengelola broadcast dan streaming lokasi real-time
// anggota grup menggunakan Supabase Realtime Broadcast (WebSocket).
// Tidak membebani database write cost sama sekali.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location_model.dart';
import '../supabase_config.dart';

/// [LocationService] mengelola transmisi koordinat GPS secara real-time
/// menggunakan Supabase Realtime Channels (Broadcast event).
class LocationService {
  SupabaseClient get _supabase => SupabaseConfig.client;

  RealtimeChannel? _channel;
  String? _currentGroupId;
  final Map<String, MemberLocation> _groupLocations = {};
  StreamController<List<MemberLocation>>? _locationStreamController;

  /// Broadcast lokasi pengguna ke channel Supabase grup.
  /// Event: 'location_update'
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

    // Update state lokal kita sendiri juga
    _groupLocations[uid] = location;
    _emitLocations();

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'location_update',
        payload: location.toMap(),
      );
    } catch (e) {
      debugPrint('Error broadcasting location: $e');
    }
  }

  /// Stream lokasi semua anggota dalam satu grup.
  /// Mengembalikan `Stream<List<MemberLocation>>`.
  Stream<List<MemberLocation>> streamGroupLocations(String groupId) {
    if (_currentGroupId != groupId) {
      _currentGroupId = groupId;
      _groupLocations.clear();
      _setupChannel(groupId);
    }

    _locationStreamController ??= StreamController<List<MemberLocation>>.broadcast(
      onCancel: () {
        // Jangan langsung tutup jika masih dibutuhkan
      },
    );

    // Kirim state saat ini jika ada
    _emitLocations();

    return _locationStreamController!.stream;
  }

  RealtimeChannel _ensureChannel(String groupId) {
    if (_channel != null && _currentGroupId == groupId) {
      return _channel!;
    }
    _setupChannel(groupId);
    return _channel!;
  }

  void _setupChannel(String groupId) {
    _channel?.unsubscribe();
    _currentGroupId = groupId;

    _channel = _supabase.channel('group_tracking:$groupId');

    _channel!
        .onBroadcast(
          event: 'location_update',
          callback: (message) {
            try {
              final data = _unwrap(message);
              if (data == null) return;
              final loc = MemberLocation.fromMap(data);
              if (_isValidLocation(loc)) {
                _groupLocations[loc.uid] = loc;
                _emitLocations();
              }
            } catch (e) {
              debugPrint('Error parsing broadcast location: $e');
            }
          },
        )
        .onBroadcast(
          event: 'status_update',
          callback: (message) {
            try {
              final data = _unwrap(message);
              if (data == null) return;
              final uid = data['uid'] as String?;
              final status = data['status'] as String?;
              if (uid != null &&
                  _allowedStatuses.contains(status) &&
                  _groupLocations.containsKey(uid)) {
                _groupLocations[uid] = _groupLocations[uid]!.copyWith(status: status);
                _emitLocations();
              }
            } catch (e) {
              debugPrint('Error parsing broadcast status: $e');
            }
          },
        )
        .onBroadcast(
          event: 'request_sync',
          callback: (payload) {
            // Ketika member baru minta sync, broadcast ulang lokasi diri sendiri jika ada
            final myUid = _supabase.auth.currentUser?.id;
            if (myUid != null && _groupLocations.containsKey(myUid)) {
              _channel?.sendBroadcastMessage(
                event: 'location_update',
                payload: _groupLocations[myUid]!.toMap(),
              );
            }
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        final myUid = _supabase.auth.currentUser?.id;
        // Jika posisi awal kita sudah diambil sebelum channel selesai subscribe, kirim sekarang
        if (myUid != null && _groupLocations.containsKey(myUid)) {
          _channel?.sendBroadcastMessage(
            event: 'location_update',
            payload: _groupLocations[myUid]!.toMap(),
          );
        }
        // Minta anggota lain untuk mengirim koordinat mereka
        _channel?.sendBroadcastMessage(
          event: 'request_sync',
          payload: {'from': myUid},
        );
      }
    });
  }

  static const Set<String> _allowedStatuses = {'online', 'offline', 'sos'};

  /// Callback `onBroadcast` menerima amplop `{type, event, payload}`.
  /// Data sebenarnya berada di dalam key `payload`.
  Map<String, dynamic>? _unwrap(Map<String, dynamic> message) {
    final inner = message['payload'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return null;
  }

  /// Validasi data dari peer (tidak dipercaya): uid, rentang koordinat, status.
  bool _isValidLocation(MemberLocation loc) {
    return loc.uid.isNotEmpty &&
        loc.lat.isFinite &&
        loc.lng.isFinite &&
        loc.lat >= -90 &&
        loc.lat <= 90 &&
        loc.lng >= -180 &&
        loc.lng <= 180 &&
        _allowedStatuses.contains(loc.status);
  }

  void _emitLocations() {
    if (_locationStreamController != null && !_locationStreamController!.isClosed) {
      _locationStreamController!.add(_groupLocations.values.toList());
    }
  }

  /// Set status user menjadi 'offline' saat keluar dari grup.
  Future<void> setOffline({
    required String groupId,
    required String uid,
  }) async {
    if (_groupLocations.containsKey(uid)) {
      _groupLocations[uid] = _groupLocations[uid]!.copyWith(status: 'offline');
      _emitLocations();
    }

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'status_update',
        payload: {
          'uid': uid,
          'status': 'offline',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('Error broadcasting offline status: $e');
    }
  }

  /// Hapus data lokasi user dari memori lokal grup.
  Future<void> removeLocation({
    required String groupId,
    required String uid,
  }) async {
    _groupLocations.remove(uid);
    _emitLocations();
  }

  /// Bersihkan channel dan data grup saat grup berakhir.
  Future<void> cleanupGroupLocations(String groupId) async {
    _groupLocations.clear();
    _emitLocations();
    _channel?.unsubscribe();
    _channel = null;
    _currentGroupId = null;
  }

  /// Aktifkan sinyal SOS untuk user.
  Future<void> triggerSOS({
    required String groupId,
    required String uid,
  }) async {
    if (_groupLocations.containsKey(uid)) {
      _groupLocations[uid] = _groupLocations[uid]!.copyWith(status: 'sos');
      _emitLocations();
    }

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'status_update',
        payload: {
          'uid': uid,
          'status': 'sos',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('Error broadcasting SOS: $e');
    }
  }

  /// Batalkan sinyal SOS (kembali ke 'online').
  Future<void> cancelSOS({
    required String groupId,
    required String uid,
  }) async {
    if (_groupLocations.containsKey(uid)) {
      _groupLocations[uid] = _groupLocations[uid]!.copyWith(status: 'online');
      _emitLocations();
    }

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'status_update',
        payload: {
          'uid': uid,
          'status': 'online',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('Error broadcasting cancel SOS: $e');
    }
  }
}
