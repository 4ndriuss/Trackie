// File: location_service.dart
// Service untuk mengelola broadcast dan streaming lokasi real-time
// anggota grup serta titik tujuan (destination) menggunakan Supabase Realtime Broadcast (WebSocket).
// Tidak membebani database write cost sama sekali.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location_model.dart';
import '../supabase_config.dart';
import 'routing_service.dart';

/// [LocationService] mengelola transmisi koordinat GPS dan titik tujuan secara real-time
/// menggunakan Supabase Realtime Channels (Broadcast event).
class LocationService {
  /// Nama topic Realtime untuk grup. Format ini HARUS sama dengan yang
  /// diperiksa fungsi SQL `public.can_access_tracking_topic`.
  static String trackingTopic(String groupId) => 'group_tracking:$groupId';

  final SupabaseClient? _injectedClient;

  LocationService({SupabaseClient? supabaseClient}) : _injectedClient = supabaseClient;

  SupabaseClient get _supabase => _injectedClient ?? SupabaseConfig.client;

  RealtimeChannel? _channel;
  bool _isChannelSubscribed = false;
  String? _currentGroupId;
  String? _expectedHostUid;
  String? _myUid;
  final Map<String, MemberLocation> _groupLocations = {};
  final Set<String> _knownMemberUids = {};
  DestinationTarget? _groupDestination;
  StreamController<List<MemberLocation>>? _locationStreamController;
  StreamController<DestinationTarget?>? _destinationStreamController;
  StreamController<String>? _groupEndedStreamController;

  /// Membungkus payload broadcast agar kompatibel dengan Supabase Realtime
  /// Protocol v2 (`vsn=2.0.0`), Protocol v1 (`vsn=1.0.0`), maupun REST fallback.
  static Map<String, dynamic> wrapBroadcastPayload(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    return <String, dynamic>{
      ...copy,
      'payload': Map<String, dynamic>.from(copy),
    };
  }

  /// Konfigurasikan UID Host grup yang diharapkan untuk memvalidasi
  /// broadcast resmi (seperti pembaruan destinasi atau grup diakhiri - BACK-03).
  void setExpectedHostUid(String? hostUid) {
    _expectedHostUid = hostUid;
  }

  /// UID Host yang diharapkan saat ini.
  String? get expectedHostUid => _expectedHostUid;

  /// Stream notifikasi saat grup telah diakhiri oleh Host.
  Stream<String> get onGroupEnded {
    _groupEndedStreamController ??= StreamController<String>.broadcast();
    return _groupEndedStreamController!.stream;
  }

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
    // Validasi & pastikan UID autentik (cegah impersonasi / spoofing UID anggota lain - BACK-03)
    final authenticatedUid = _supabase.auth.currentUser?.id;
    final effectiveUid = (authenticatedUid != null && authenticatedUid.isNotEmpty)
        ? authenticatedUid
        : uid;

    _myUid = effectiveUid;

    final location = MemberLocation(
      uid: effectiveUid,
      name: name,
      lat: lat,
      lng: lng,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      status: status,
    );

    // Update state lokal kita sendiri juga
    _groupLocations[effectiveUid] = location;
    _emitLocations();

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'location_update',
        payload: wrapBroadcastPayload(location.toMap()),
      );
      _trackMyPresence(location);
    } catch (e) {
      debugPrint('Error broadcasting location: $e');
    }
  }

  void _trackMyPresence(MemberLocation location) {
    final channel = _channel;
    if (channel != null && _isChannelSubscribed) {
      unawaited(
        channel
            .track(location.toMap())
            .catchError((_) => ChannelResponse.error),
      );
    }
  }

  void _rebroadcastMyState() {
    final channel = _channel;
    if (channel == null) return;
    final myUid = _supabase.auth.currentUser?.id ?? _myUid;
    if (myUid != null && _groupLocations.containsKey(myUid)) {
      final myLoc = _groupLocations[myUid]!;
      unawaited(
        channel
            .sendBroadcastMessage(
              event: 'location_update',
              payload: wrapBroadcastPayload(myLoc.toMap()),
            )
            .catchError((_) => ChannelResponse.error),
      );
      _trackMyPresence(myLoc);
    }
    if (_groupDestination != null) {
      unawaited(
        channel
            .sendBroadcastMessage(
              event: 'destination_update',
              payload: wrapBroadcastPayload(_destinationPayload(_groupDestination!)),
            )
            .catchError((_) => ChannelResponse.error),
      );
    }
  }

  /// Sinkronkan daftar anggota grup dari tabel `public.groups` (`member_uids`) dan `public.profiles`
  /// agar teman yang baru join langsung muncul di peta & daftar anggota, serta memicu pertukaran koordinat.
  void syncRegisteredMembers({
    required String groupId,
    required List<String> memberUids,
    required Map<String, String> memberNames,
    required double fallbackLat,
    required double fallbackLng,
    String? currentUid,
  }) {
    _ensureChannel(groupId);
    final effectiveMyUid = _supabase.auth.currentUser?.id ?? currentUid ?? _myUid;
    final cleanUids = memberUids.where((u) => u.trim().isNotEmpty).toSet();
    if (effectiveMyUid != null && effectiveMyUid.isNotEmpty) {
      cleanUids.add(effectiveMyUid);
    }

    bool changed = false;
    bool hasNewPeer = false;

    // Hapus anggota yang sudah keluar dari grup
    final toRemove = _groupLocations.keys
        .where((k) => !cleanUids.contains(k) && k != effectiveMyUid)
        .toList();
    for (final uid in toRemove) {
      _groupLocations.remove(uid);
      changed = true;
    }

    for (final uid in cleanUids) {
      if (!_knownMemberUids.contains(uid) && uid != effectiveMyUid) {
        hasNewPeer = true;
      }
      final profileName = memberNames[uid]?.trim();
      final existing = _groupLocations[uid];
      if (existing == null) {
        // Tambahkan entry awal agar ikon teman langsung muncul saat join grup
        _groupLocations[uid] = MemberLocation(
          uid: uid,
          name: (profileName != null && profileName.isNotEmpty)
              ? profileName
              : (uid == effectiveMyUid ? 'Anda' : 'Anggota Grup'),
          lat: fallbackLat,
          lng: fallbackLng,
          timestamp: 0,
          status: 'online',
        );
        changed = true;
      } else if (profileName != null &&
          profileName.isNotEmpty &&
          (existing.name.isEmpty ||
              existing.name == 'Anggota Grup' ||
              existing.name == 'Teman Grup')) {
        _groupLocations[uid] = existing.copyWith(name: profileName);
        changed = true;
      }
    }

    _knownMemberUids
      ..clear()
      ..addAll(cleanUids);

    if (changed) {
      _emitLocations();
    }

    if (hasNewPeer) {
      resyncWithPeers();
    }
  }

  /// Meminta sinkronisasi ulang lokasi dengan seluruh anggota di channel.
  void resyncWithPeers() {
    _rebroadcastMyState();
    final myUid = _supabase.auth.currentUser?.id ?? _myUid;
    final channel = _channel;
    if (channel != null) {
      unawaited(
        channel
            .sendBroadcastMessage(
              event: 'request_sync',
              payload: wrapBroadcastPayload({'from': myUid ?? ''}),
            )
            .catchError((_) => ChannelResponse.error),
      );
    }
  }

  /// Broadcast pembaruan titik tujuan (oleh Host) ke seluruh anggota grup.
  /// Event: 'destination_update'
  Future<void> broadcastDestination({
    required String groupId,
    required DestinationTarget target,
    String? hostUid,
  }) async {
    final currentUid = _supabase.auth.currentUser?.id;
    final effectiveHostUid = hostUid ?? _expectedHostUid ?? currentUid;

    // Sinkronisasi ke database lewat RPC berotorisasi Host (BACK-03)
    try {
      await _supabase.rpc('set_group_destination', params: {
        'p_group_id': groupId,
        'p_destination': RoutingService.encodeDestination(
          target.name,
          target.point,
        ),
      });
    } catch (e) {
      debugPrint('Catatan: RPC set_group_destination: $e');
    }

    _groupDestination = target;
    _emitDestination();

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'destination_update',
        payload: wrapBroadcastPayload(_destinationPayload(target, effectiveHostUid)),
      );
    } catch (e) {
      debugPrint('Error broadcasting destination: $e');
    }
  }

  /// Stream titik tujuan grup secara real-time.
  Stream<DestinationTarget?> streamGroupDestination(String groupId) {
    if (_currentGroupId != groupId) {
      _currentGroupId = groupId;
      _groupLocations.clear();
      _groupDestination = null;
      _setupChannel(groupId);
    }

    _destinationStreamController ??=
        StreamController<DestinationTarget?>.broadcast();
    _emitDestination();
    return _destinationStreamController!.stream;
  }

  /// Stream lokasi semua anggota dalam satu grup.
  /// Mengembalikan `Stream<List<MemberLocation>>`.
  Stream<List<MemberLocation>> streamGroupLocations(String groupId) {
    if (_currentGroupId != groupId) {
      _currentGroupId = groupId;
      _groupLocations.clear();
      _groupDestination = null;
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
    _isChannelSubscribed = false;
    _channel?.unsubscribe();
    _currentGroupId = groupId;

    final presenceKey = _supabase.auth.currentUser?.id ?? _myUid ?? '';

    _channel = _supabase.channel(
      trackingTopic(groupId),
      opts: RealtimeChannelConfig(
        ack: true,
        key: presenceKey,
      ),
    );

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
          event: 'destination_update',
          callback: (message) {
            try {
              final data = _unwrap(message);
              if (data == null) return;

              // Validasi Host (BACK-03): Abaikan jika ada host_uid dan tidak cocok dengan Host grup
              final senderHostUid = data['host_uid'] as String?;
              if (_expectedHostUid != null &&
                  senderHostUid != null &&
                  senderHostUid != _expectedHostUid) {
                debugPrint(
                    'Peringatan: destination_update ditolak dari pengirim ilegal: $senderHostUid');
                return;
              }

              final target = DestinationTarget.fromMap(data);
              if (target.point.latitude.isFinite &&
                  target.point.longitude.isFinite &&
                  target.point.latitude >= -90 &&
                  target.point.latitude <= 90 &&
                  target.point.longitude >= -180 &&
                  target.point.longitude <= 180) {
                _groupDestination = target;
                _emitDestination();
              }
            } catch (e) {
              debugPrint('Error parsing broadcast destination: $e');
            }
          },
        )
        .onBroadcast(
          event: 'request_sync',
          callback: (payload) {
            // Ketika member baru minta sync, broadcast ulang lokasi & tujuan diri sendiri jika ada
            _rebroadcastMyState();
          },
        )
        .onBroadcast(
          event: 'group_ended',
          callback: (message) {
            try {
              final data = _unwrap(message);

              // Validasi Host (BACK-03): Abaikan jika pengirim bukan host grup sah
              final senderHostUid = data?['host_uid'] as String?;
              if (_expectedHostUid != null &&
                  senderHostUid != null &&
                  senderHostUid != _expectedHostUid) {
                debugPrint(
                    'Peringatan: group_ended ditolak dari pengirim ilegal: $senderHostUid');
                return;
              }

              final endedGroupId = data?['group_id'] as String? ?? groupId;
              _groupEndedStreamController?.add(endedGroupId);
            } catch (e) {
              debugPrint('Error handling group_ended broadcast: $e');
            }
          },
        )
        .onPresenceSync((_) {
          _syncFromPresence();
        })
        .onPresenceJoin((_) {
          _syncFromPresence();
          // Saat teman baru join ke channel, langsung kirim lokasi & tujuan terkini kita
          _rebroadcastMyState();
        })
        .subscribe((status, error) {
      _isChannelSubscribed = status == RealtimeSubscribeStatus.subscribed;
      if (_isChannelSubscribed) {
        _rebroadcastMyState();
        final myUid = _supabase.auth.currentUser?.id ?? _myUid;
        // Minta anggota lain untuk mengirim koordinat & tujuan mereka
        _channel?.sendBroadcastMessage(
          event: 'request_sync',
          payload: wrapBroadcastPayload({'from': myUid ?? ''}),
        );
      }
    });
  }

  void _syncFromPresence() {
    final channel = _channel;
    if (channel == null) return;
    try {
      bool changed = false;
      for (final state in channel.presenceState()) {
        for (final presence in state.presences) {
          final data = _unwrap(presence.payload) ?? presence.payload;
          final loc = MemberLocation.fromMap(data);
          if (_isValidLocation(loc)) {
            final existing = _groupLocations[loc.uid];
            if (existing == null || loc.timestamp >= existing.timestamp) {
              _groupLocations[loc.uid] = loc;
              changed = true;
            }
          }
        }
      }
      if (changed) {
        _emitLocations();
      }
    } catch (e) {
      debugPrint('Error syncing presence locations: $e');
    }
  }

  static const Set<String> _allowedStatuses = {'online', 'offline', 'sos'};

  /// Membuka amplop pesan broadcast baik dari format nested `payload` (Protocol v2 / REST)
  /// maupun format flat map (Protocol v1).
  Map<String, dynamic>? _unwrap(Map<String, dynamic> message) {
    Map<String, dynamic> current = Map<String, dynamic>.from(message);
    while (current['payload'] is Map) {
      current = Map<String, dynamic>.from(current['payload'] as Map);
    }
    if (current.isNotEmpty) {
      return current;
    }
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

  Map<String, dynamic> _destinationPayload(
    DestinationTarget target, [
    String? hostUid,
  ]) {
    final payload = Map<String, dynamic>.from(target.toMap());
    final effective = hostUid ?? _expectedHostUid;
    if (effective != null && effective.isNotEmpty) {
      payload['host_uid'] = effective;
    }
    return payload;
  }

  void _emitDestination() {
    if (_destinationStreamController != null &&
        !_destinationStreamController!.isClosed) {
      _destinationStreamController!.add(_groupDestination);
    }
  }

  /// Set status user menjadi 'offline' saat keluar dari grup.
  Future<void> setOffline({
    required String groupId,
    required String uid,
  }) async {
    final authenticatedUid = _supabase.auth.currentUser?.id;
    final effectiveUid =
        (authenticatedUid != null && authenticatedUid.isNotEmpty)
            ? authenticatedUid
            : uid;

    if (_groupLocations.containsKey(effectiveUid)) {
      _groupLocations[effectiveUid] =
          _groupLocations[effectiveUid]!.copyWith(status: 'offline');
      _emitLocations();
      _trackMyPresence(_groupLocations[effectiveUid]!);
    }

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'status_update',
        payload: wrapBroadcastPayload({
          'uid': effectiveUid,
          'status': 'offline',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
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
    _knownMemberUids.clear();
    _groupDestination = null;
    _expectedHostUid = null;
    _myUid = null;
    _emitLocations();
    _emitDestination();
    _isChannelSubscribed = false;
    _channel?.unsubscribe();
    _channel = null;
    _currentGroupId = null;
  }

  /// Broadcast event bahwa perjalanan grup telah diakhiri oleh Host.
  Future<void> broadcastGroupEnded(String groupId, {String? hostUid}) async {
    final channel = _ensureChannel(groupId);
    final currentUid = _supabase.auth.currentUser?.id;
    final effectiveHostUid = hostUid ?? _expectedHostUid ?? currentUid;

    final payload = <String, dynamic>{
      'group_id': groupId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (effectiveHostUid != null && effectiveHostUid.isNotEmpty) {
      payload['host_uid'] = effectiveHostUid;
    }

    try {
      await channel.sendBroadcastMessage(
        event: 'group_ended',
        payload: wrapBroadcastPayload(payload),
      );
    } catch (e) {
      debugPrint('Error broadcasting group_ended: $e');
    }
  }

  /// Aktifkan sinyal SOS untuk user.
  Future<void> triggerSOS({
    required String groupId,
    required String uid,
  }) async {
    final authenticatedUid = _supabase.auth.currentUser?.id;
    final effectiveUid =
        (authenticatedUid != null && authenticatedUid.isNotEmpty)
            ? authenticatedUid
            : uid;

    if (_groupLocations.containsKey(effectiveUid)) {
      _groupLocations[effectiveUid] =
          _groupLocations[effectiveUid]!.copyWith(status: 'sos');
      _emitLocations();
      _trackMyPresence(_groupLocations[effectiveUid]!);
    }

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'status_update',
        payload: wrapBroadcastPayload({
          'uid': effectiveUid,
          'status': 'sos',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
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
    final authenticatedUid = _supabase.auth.currentUser?.id;
    final effectiveUid =
        (authenticatedUid != null && authenticatedUid.isNotEmpty)
            ? authenticatedUid
            : uid;

    if (_groupLocations.containsKey(effectiveUid)) {
      _groupLocations[effectiveUid] =
          _groupLocations[effectiveUid]!.copyWith(status: 'online');
      _emitLocations();
      _trackMyPresence(_groupLocations[effectiveUid]!);
    }

    final channel = _ensureChannel(groupId);
    try {
      await channel.sendBroadcastMessage(
        event: 'status_update',
        payload: wrapBroadcastPayload({
          'uid': effectiveUid,
          'status': 'online',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('Error broadcasting cancel SOS: $e');
    }
  }
}
