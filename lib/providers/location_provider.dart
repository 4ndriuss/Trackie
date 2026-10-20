// File: location_provider.dart
// Provider untuk mengelola state lokasi real-time anggota grup serta rute navigasi.
// Mengintegrasikan LocationService (Supabase Realtime Broadcast), BackgroundLocationService
// (Foreground Service), RoutingService (OSRM & Nominatim), dan PermissionService.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import '../services/background_location_service.dart';
import '../services/permission_service.dart';
import '../services/routing_service.dart';
import '../services/haversine_utils.dart';
import '../models/location_model.dart';
import '../models/trip_history_model.dart';
import '../supabase_config.dart';

/// [LocationProvider] mengelola:
/// - Stream GPS langsung dari perangkat (`Geolocator.getPositionStream`)
/// - Stream lokasi anggota grup dari Supabase Realtime Broadcast
/// - Sinkronisasi titik tujuan & perhitungan rute jalan raya (OSRM) untuk setiap anggota
/// - Perekaman jejak koordinat untuk disimpan ke Riwayat Perjalanan (`trip_history`)
/// - Background tracking via Foreground Service saat aplikasi di latar belakang
/// - Permission handling untuk lokasi
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final RoutingService _routingService = RoutingService();

  List<MemberLocation> _members = [];
  StreamSubscription? _locationSubscription;
  StreamSubscription<DestinationTarget?>? _destinationSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _tokenRefreshTimer;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _permissionsGranted = false;
  String? _error;

  String? _currentUid;
  String _vehicleType = 'motor';
  String _currentMemberStatus = 'online';
  DestinationTarget? _destinationTarget;
  RouteResult? _activeRoute;
  bool _isLoadingRoute = false;
  LatLng? _lastRoutedOrigin;
  LatLng? _lastRoutedDestination;
  DateTime? _lastRouteFetchTime;

  final List<LatLng> _recordedPath = [];
  DateTime? _tripStartedAt;

  List<MemberLocation> get members => _members;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get permissionsGranted => _permissionsGranted;
  String? get error => _error;
  DestinationTarget? get destinationTarget => _destinationTarget;
  RouteResult? get activeRoute => _activeRoute;
  bool get isLoadingRoute => _isLoadingRoute;

  /// Minta semua izin yang diperlukan untuk tracking.
  /// Mengembalikan true jika izin lokasi diberikan.
  Future<bool> requestPermissions() async {
    _permissionsGranted =
        await PermissionService.requestAllTrackingPermissions();
    notifyListeners();
    return _permissionsGranted;
  }

  /// Mulai mendengarkan perubahan lokasi seluruh anggota grup & tujuan,
  /// memulai live GPS stream di foreground, DAN memulai background location tracking.
  Future<void> startTracking({
    required String groupId,
    required String uid,
    required String userName,
    String? tripName,
    String? initialDestination,
    String vehicleType = 'motor',
  }) async {
    stopListening();
    _isTracking = true;
    _currentUid = uid;
    _vehicleType = vehicleType;
    _currentMemberStatus = 'online';
    _tripStartedAt = DateTime.now();
    _recordedPath.clear();
    _error = null;

    // 1. Listen perubahan lokasi anggota dari Supabase Realtime
    _locationSubscription = _locationService
        .streamGroupLocations(groupId)
        .listen((locations) {
      _members = locations;
      _maybeRefreshRouteForCurrentPosition();
      notifyListeners();
    }, onError: (e) {
      _error = 'Gagal menerima lokasi anggota.';
      debugPrint('Error streaming locations: $e');
      notifyListeners();
    });

    // 2. Listen perubahan titik tujuan dari Host secara real-time
    _destinationSubscription = _locationService
        .streamGroupDestination(groupId)
        .listen((target) {
      if (target != null) {
        final changed = _destinationTarget?.point != target.point ||
            _destinationTarget?.name != target.name;
        _destinationTarget = target;
        if (changed) {
          unawaited(_calculateRoute(force: true));
        }
        notifyListeners();
      }
    });

    // 3. Ambil posisi GPS asli perangkat terlebih dahulu
    unawaited(
      _acquireAndBroadcastPosition(
        groupId: groupId,
        uid: uid,
        userName: userName,
      ),
    );
    _startForegroundPositionStream(
      groupId: groupId,
      uid: uid,
      userName: userName,
    );

    // 4. Resolusi tujuan awal dari data grup
    if (initialDestination != null && initialDestination.trim().isNotEmpty) {
      unawaited(_resolveInitialDestination(groupId, initialDestination));
    }

    // 5. Mulai background tracking (Foreground Service) untuk Android/iOS saat layar dikunci
    if (!kIsWeb) {
      try {
        await BackgroundLocationService.startTracking(
          groupId: groupId,
          uid: uid,
          userName: userName,
          accessToken: SupabaseConfig.client.auth.currentSession?.accessToken,
          tripName: tripName,
        );
        _startTokenSync();
      } catch (e) {
        debugPrint('Error starting background service: $e');
      }
    }

    notifyListeners();
  }

  void _recordPoint(double lat, double lng) {
    final pt = LatLng(lat, lng);
    if (_recordedPath.isEmpty) {
      _recordedPath.add(pt);
      return;
    }
    final last = _recordedPath.last;
    final dist = HaversineUtils.distanceInMeters(
      last.latitude,
      last.longitude,
      lat,
      lng,
    );
    if (dist >= 5) {
      _recordedPath.add(pt);
    }
  }

  /// Menyusun objek [TripHistoryModel] saat perjalanan selesai untuk disimpan ke Supabase.
  TripHistoryModel buildCompletedTripHistory({
    required String groupName,
    required String rawDestination,
    required String groupType,
    required bool isHost,
    required int fallbackMemberCount,
    DateTime? groupCreatedAt,
  }) {
    final endedAt = DateTime.now();
    final startedAt = _tripStartedAt ??
        groupCreatedAt ??
        endedAt.subtract(const Duration(minutes: 15));

    final cleanDest = _destinationTarget?.name ??
        RoutingService.cleanDestinationName(rawDestination);

    // Gunakan jejak GPS yang terekam jika ada minimal 2 titik, atau gunakan garis rute aktif
    List<LatLng> pathPoints = List<LatLng>.from(_recordedPath);
    if (pathPoints.length < 2 &&
        _activeRoute != null &&
        _activeRoute!.points.isNotEmpty) {
      // Sampling titik rute agar penyimpanan JSONB di database tetap ringan & cepat
      final rawRoute = _activeRoute!.points;
      if (rawRoute.length <= 80) {
        pathPoints = List<LatLng>.from(rawRoute);
      } else {
        final step = (rawRoute.length / 80).ceil();
        pathPoints = [
          for (int i = 0; i < rawRoute.length; i += step) rawRoute[i],
          rawRoute.last,
        ];
      }
    } else if (pathPoints.length == 1 && _destinationTarget != null) {
      pathPoints.add(_destinationTarget!.point);
    }

    // Hitung total jarak tempuh (km)
    double totalMeters = 0.0;
    for (int i = 1; i < pathPoints.length; i++) {
      totalMeters += HaversineUtils.distanceInMeters(
        pathPoints[i - 1].latitude,
        pathPoints[i - 1].longitude,
        pathPoints[i].latitude,
        pathPoints[i].longitude,
      );
    }
    if (totalMeters < 50 && _activeRoute != null) {
      totalMeters = _activeRoute!.distanceMeters;
    }
    final distanceKm = double.parse((totalMeters / 1000.0).toStringAsFixed(1));

    // Format durasi perjalanan
    final diff = endedAt.difference(startedAt);
    final totalMinutes = diff.inMinutes.clamp(1, 99999);
    final String durationStr;
    if (totalMinutes < 60) {
      durationStr = '${totalMinutes}m';
    } else {
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      durationStr = m > 0 ? '${h}h ${m}m' : '${h}h';
    }

    final activeMemberCount =
        _members.length > fallbackMemberCount ? _members.length : fallbackMemberCount;

    final encodedGroupName = TripHistoryModel.encodeGroupMeta(
      groupName: groupName,
      destination: cleanDest,
      role: isHost ? 'Host' : 'Member',
    );

    final routePathMaps = pathPoints
        .map(
          (p) => <String, double>{
            'lat': double.parse(p.latitude.toStringAsFixed(6)),
            'lng': double.parse(p.longitude.toStringAsFixed(6)),
          },
        )
        .toList();

    return TripHistoryModel(
      id: '',
      groupName: encodedGroupName,
      groupType: groupType,
      distanceKm: distanceKm,
      duration: durationStr,
      routePath: routePathMaps,
      memberCount: activeMemberCount.clamp(1, 999),
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  /// Mengambil lokasi GPS asli secepat mungkin:
  /// 1. Cek `getLastKnownPosition()` (instan) agar peta & rute langsung berada di daerah pengguna
  /// 2. Lanjutkan dengan `getCurrentPosition()` untuk akurasi tinggi terbaru
  Future<void> _acquireAndBroadcastPosition({
    required String groupId,
    required String uid,
    required String userName,
  }) async {
    try {
      await PermissionService.requestLocationPermission();

      if (!kIsWeb && _currentPosition == null) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null && _currentPosition == null) {
            _currentPosition = lastKnown;
            _recordPoint(lastKnown.latitude, lastKnown.longitude);
            await _locationService.updateLocation(
              groupId: groupId,
              uid: uid,
              name: userName,
              lat: lastKnown.latitude,
              lng: lastKnown.longitude,
              status: _currentMemberStatus,
            );
            _maybeRefreshRouteForCurrentPosition(forceIfFirstFix: true);
            notifyListeners();
          }
        } catch (_) {}
      }

      await broadcastLocation(groupId: groupId, uid: uid, name: userName);
    } catch (e) {
      debugPrint('Error acquiring initial position: $e');
    }
  }

  /// Mendengarkan pergerakan GPS secara langsung (real-time) dari sensor perangkat.
  void _startForegroundPositionStream({
    required String groupId,
    required String uid,
    required String userName,
  }) {
    _positionStreamSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update setiap bergerak >= 5 meter
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position pos) {
        final isFirstFix = _currentPosition == null;
        _currentPosition = pos;
        _recordPoint(pos.latitude, pos.longitude);
        unawaited(
          _locationService.updateLocation(
            groupId: groupId,
            uid: uid,
            name: userName,
            lat: pos.latitude,
            lng: pos.longitude,
            status: _currentMemberStatus,
          ),
        );
        _maybeRefreshRouteForCurrentPosition(forceIfFirstFix: isFirstFix);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Foreground GPS stream error: $e');
      },
    );
  }

  Future<void> _resolveInitialDestination(
    String groupId,
    String rawDestination,
  ) async {
    final embedded = RoutingService.tryParseEmbeddedDestination(rawDestination);
    if (embedded != null) {
      _destinationTarget ??= embedded;
      notifyListeners();
      await _locationService.broadcastDestination(
        groupId: groupId,
        target: embedded,
      );
      await _calculateRoute(force: true);
      return;
    }

    final cleanName = RoutingService.cleanDestinationName(rawDestination);
    if (cleanName.isEmpty) return;

    final places = await _routingService.searchPlaces(cleanName);
    if (places.isEmpty) return;

    if (_destinationTarget == null) {
      final resolved = DestinationTarget(
        name: cleanName,
        point: places.first.point,
      );
      _destinationTarget = resolved;
      notifyListeners();
      await _locationService.broadcastDestination(
        groupId: groupId,
        target: resolved,
      );
      await _calculateRoute(force: true);
    }
  }

  /// Mengubah titik tujuan grup (dipanggil oleh Host saat memilih lokasi baru / tap di peta)
  /// dan menyebarkannya secara real-time ke seluruh anggota grup.
  Future<void> updateGroupDestination({
    String? groupId,
    required DestinationTarget target,
  }) async {
    _destinationTarget = target;
    notifyListeners();
    if (groupId != null && groupId.isNotEmpty) {
      await _locationService.broadcastDestination(
        groupId: groupId,
        target: target,
      );
    }
    await _calculateRoute(force: true);
  }

  /// Mengambil titik GPS asli pengguna saat ini.
  LatLng? get myLatLng {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    if (_currentUid != null) {
      for (final m in _members) {
        if (m.uid == _currentUid) {
          return LatLng(m.lat, m.lng);
        }
      }
    }
    return null;
  }

  void _maybeRefreshRouteForCurrentPosition({bool forceIfFirstFix = false}) {
    if (_destinationTarget == null) return;
    final origin = myLatLng;
    if (origin == null) return;

    if (forceIfFirstFix || _activeRoute == null || _lastRoutedOrigin == null) {
      unawaited(_calculateRoute(force: true));
      return;
    }

    final movedMeters = HaversineUtils.distanceInMeters(
      origin.latitude,
      origin.longitude,
      _lastRoutedOrigin!.latitude,
      _lastRoutedOrigin!.longitude,
    );

    if (movedMeters >= 250) {
      unawaited(_calculateRoute(force: true));
      return;
    }

    final now = DateTime.now();
    final elapsedSeconds = _lastRouteFetchTime == null
        ? 999
        : now.difference(_lastRouteFetchTime!).inSeconds;

    if (movedMeters >= 50 && elapsedSeconds >= 12) {
      unawaited(_calculateRoute(force: false));
    }
  }

  /// Meminta perhitungan rute jalan raya dari posisi GPS asli pengguna menuju tujuan grup.
  Future<void> _calculateRoute({bool force = false}) async {
    final target = _destinationTarget;
    if (target == null) return;

    LatLng? origin = myLatLng;
    if (origin == null) {
      try {
        await PermissionService.requestLocationPermission();
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _currentPosition = pos;
        _recordPoint(pos.latitude, pos.longitude);
        origin = LatLng(pos.latitude, pos.longitude);
      } catch (_) {
        if (!kIsWeb) {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            _currentPosition = last;
            _recordPoint(last.latitude, last.longitude);
            origin = LatLng(last.latitude, last.longitude);
          }
        }
      }
    }

    if (origin == null) return;

    if (!force &&
        _lastRoutedOrigin != null &&
        _lastRoutedDestination == target.point) {
      final moved = HaversineUtils.distanceInMeters(
        origin.latitude,
        origin.longitude,
        _lastRoutedOrigin!.latitude,
        _lastRoutedOrigin!.longitude,
      );
      if (moved < 25 && _activeRoute != null) return;
    }

    _isLoadingRoute = true;
    _lastRoutedOrigin = origin;
    _lastRoutedDestination = target.point;
    _lastRouteFetchTime = DateTime.now();
    notifyListeners();

    try {
      final route = await _routingService.getRoute(
        origin: origin,
        destination: target.point,
        vehicleType: _vehicleType,
      );
      _activeRoute = route;
    } catch (e) {
      debugPrint('Error calculating route: $e');
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  /// Sinkronkan access token ke background isolate selama tracking.
  void _startTokenSync() {
    _stopTokenSync();
    final auth = SupabaseConfig.client.auth;

    _authSubscription = auth.onAuthStateChange.listen((data) {
      final token = data.session?.accessToken;
      if (token != null &&
          (data.event == AuthChangeEvent.tokenRefreshed ||
              data.event == AuthChangeEvent.signedIn)) {
        BackgroundLocationService.updateAccessToken(token);
      }
    });

    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final expiresAt = auth.currentSession?.expiresAt;
      if (expiresAt == null) return;
      final secondsLeft =
          expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (secondsLeft < 600) {
        try {
          await auth.refreshSession();
        } catch (e) {
          debugPrint('Error refreshing session for tracking: $e');
        }
      }
    });
  }

  void _stopTokenSync() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Stream notifikasi saat Host mengakhiri grup.
  Stream<String> get onGroupEnded => _locationService.onGroupEnded;

  /// Broadcast sinyal bahwa Host telah menyelesaikan perjalanan grup.
  Future<void> broadcastGroupEnded(String groupId) async {
    await _locationService.broadcastGroupEnded(groupId);
  }

  /// Hentikan semua tracking (stream + background service).
  Future<void> stopTracking({
    String? groupId,
    String? uid,
  }) async {
    if (groupId != null && uid != null) {
      try {
        await _locationService.setOffline(groupId: groupId, uid: uid);
      } catch (e) {
        debugPrint('Error setting offline: $e');
      }
    }

    _stopTokenSync();
    if (!kIsWeb) {
      try {
        await BackgroundLocationService.stopTracking();
      } catch (e) {
        debugPrint('Error stopping background service: $e');
      }
    }

    stopListening();

    if (groupId != null) {
      await _locationService.cleanupGroupLocations(groupId);
    }
  }

  /// Hanya stop stream listener (tanpa stop background service).
  void stopListening() {
    _isTracking = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _destinationSubscription?.cancel();
    _destinationSubscription = null;
    _members = [];
    _destinationTarget = null;
    _activeRoute = null;
    _lastRoutedOrigin = null;
    _lastRoutedDestination = null;
    _recordedPath.clear();
    _tripStartedAt = null;
    notifyListeners();
  }

  /// Broadcast lokasi sendiri sekali (untuk update manual / initial).
  Future<void> broadcastLocation({
    required String groupId,
    required String uid,
    required String name,
  }) async {
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        if (!kIsWeb) {
          pos = await Geolocator.getLastKnownPosition();
        }
      }
      if (pos == null) return;
      final isFirstFix = _currentPosition == null;
      _currentPosition = pos;
      _recordPoint(pos.latitude, pos.longitude);
      await _locationService.updateLocation(
        groupId: groupId,
        uid: uid,
        name: name,
        lat: pos.latitude,
        lng: pos.longitude,
        status: _currentMemberStatus,
      );
      _maybeRefreshRouteForCurrentPosition(forceIfFirstFix: isFirstFix);
      notifyListeners();
    } catch (e) {
      _error = 'Gagal mengirim lokasi.';
      debugPrint('Error broadcasting location: $e');
      notifyListeners();
    }
  }

  /// Aktifkan sinyal SOS dan sinkronkan dengan background service.
  Future<void> triggerSOS({
    required String groupId,
    required String uid,
  }) async {
    try {
      _currentMemberStatus = 'sos';
      if (!kIsWeb) {
        BackgroundLocationService.setStatus('sos');
      }
      await _locationService.triggerSOS(groupId: groupId, uid: uid);
    } catch (e) {
      debugPrint('Error triggering SOS: $e');
    }
  }

  /// Batalkan sinyal SOS dan kembalikan status ke online.
  Future<void> cancelSOS({
    required String groupId,
    required String uid,
  }) async {
    try {
      _currentMemberStatus = 'online';
      if (!kIsWeb) {
        BackgroundLocationService.setStatus('online');
      }
      await _locationService.cancelSOS(groupId: groupId, uid: uid);
    } catch (e) {
      debugPrint('Error canceling SOS: $e');
    }
  }

  @override
  void dispose() {
    _stopTokenSync();
    stopListening();
    super.dispose();
  }
}
