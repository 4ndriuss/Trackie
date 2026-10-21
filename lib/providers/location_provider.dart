// File: location_provider.dart
// Provider untuk mengelola state lokasi real-time anggota grup serta rute navigasi.
// Mengintegrasikan LocationService (Supabase Realtime Broadcast), BackgroundLocationService
// (Foreground Service), RoutingService (OSRM & Nominatim), dan PermissionService.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import '../services/background_location_service.dart';
import '../services/permission_service.dart';
import '../services/routing_service.dart';
import '../services/haversine_utils.dart';
import '../services/trip_service.dart';
import '../models/location_model.dart';
import '../models/trip_history_model.dart';
import '../models/group_model.dart';
import 'group_provider.dart';
import '../supabase_config.dart';

/// [LocationProvider] mengelola:
/// - Stream GPS langsung dari perangkat (`Geolocator.getPositionStream`)
/// - Stream lokasi anggota grup dari Supabase Realtime Broadcast
/// - Sinkronisasi titik tujuan & perhitungan rute jalan raya (OSRM) untuk setiap anggota
/// - Perekaman jejak koordinat untuk disimpan ke Riwayat Perjalanan (`trip_history`)
/// - Background tracking via Foreground Service saat aplikasi di latar belakang
/// - Permission handling untuk lokasi
class LocationProvider extends ChangeNotifier with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final RoutingService _routingService = RoutingService();

  List<MemberLocation> _members = [];
  StreamSubscription? _locationSubscription;
  StreamSubscription<DestinationTarget?>? _destinationSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription? _backgroundPositionSubscription;
  Timer? _tokenRefreshTimer;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _permissionsGranted = false;
  String? _error;

  String? _currentGroupId;
  String? _currentUid;
  String? _currentUserName;
  String _vehicleType = 'motor';
  String _currentMemberStatus = 'online';
  bool _isAppInForeground = true;
  DestinationTarget? _destinationTarget;
  RouteResult? _activeRoute;
  bool _isLoadingRoute = false;
  LatLng? _lastRoutedOrigin;
  LatLng? _lastRoutedDestination;
  DateTime? _lastRouteFetchTime;
  DateTime? _lastBroadcastTime;
  Position? _lastBroadcastPosition;

  final List<LatLng> _recordedPath = [];
  DateTime? _tripStartedAt;
  bool _isGhostMode = false;

  LocationProvider() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (e) {
      debugPrint('WidgetsBindingObserver init warning: $e');
    }
    unawaited(_initGhostMode());
  }

  Future<void> _initGhostMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isGhostMode = prefs.getBool('trackie_ghost_mode') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading ghost mode: $e');
    }
  }

  /// Aktifkan / Nonaktifkan Ghost Mode.
  /// Saat Ghost Mode aktif, lokasi tidak disiarkan ke anggota grup (WebSocket broadcast dihentikan),
  /// namun posisi tetap tampil di peta pribadi dan jejak tetap dicatat.
  Future<void> setGhostMode(bool enabled) async {
    _isGhostMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('trackie_ghost_mode', enabled);
      BackgroundLocationService.setGhostMode(enabled);
    } catch (e) {
      debugPrint('Error saving ghost mode: $e');
    }
  }

  bool get isGhostMode => _isGhostMode;
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
    String? hostUid,
  }) async {
    stopListening();
    _locationService.setExpectedHostUid(hostUid);
    _isTracking = true;
    _currentGroupId = groupId;
    _currentUid = uid;
    _currentUserName = userName;
    _vehicleType = vehicleType;
    _currentMemberStatus = 'online';
    _tripStartedAt = DateTime.now();
    _recordedPath.clear();
    _error = null;
    _isAppInForeground = true;

    // Listen koordinat dari background service untuk kontinuitas jejak
    if (!kIsWeb) {
      _backgroundPositionSubscription?.cancel();
      _backgroundPositionSubscription = FlutterBackgroundService()
          .on('background_position')
          .listen((event) {
        if (event != null) {
          final lat = (event['latitude'] as num?)?.toDouble();
          final lng = (event['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _recordPoint(lat, lng);
            final ts = event['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
            _currentPosition = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
              accuracy: 0.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            );
          }
        }
      });
    }

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
          isForeground: true, // Timer periodik background dimatikan saat foreground
          isGhostMode: _isGhostMode,
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

  /// Melakukan downsampling titik jejak koordinat agar ukuran data ringan untuk disimpan ke JSONB (PERF-18).
  static List<LatLng> downsamplePoints(List<LatLng> points, {int maxPoints = 100}) {
    if (points.length <= maxPoints) {
      return List<LatLng>.from(points);
    }
    final step = (points.length / (maxPoints - 1)).ceil();
    final result = <LatLng>[];
    for (int i = 0; i < points.length; i += step) {
      result.add(points[i]);
    }
    if (result.isEmpty || result.last != points.last) {
      result.add(points.last);
    }
    return result;
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
      pathPoints = downsamplePoints(_activeRoute!.points, maxPoints: 100);
    } else if (pathPoints.length == 1 && _destinationTarget != null) {
      pathPoints.add(_destinationTarget!.point);
    }

    // Hitung total jarak tempuh (km) menggunakan seluruh titik GPS terekam agar akurat
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

    // Downsampling titik rute sebelum disimpan ke JSONB PostgreSQL (PERF-18)
    final savedPoints = downsamplePoints(pathPoints, maxPoints: 100);
    final routePathMaps = savedPoints
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

  /// Orkestrasi selesai perjalanan terpadu (ARCH-06).
  /// Menyimpan riwayat perjalanan ke Supabase (dengan fallback offline aman BUG-01),
  /// menyiarkan event group_ended jika dipanggil oleh Host,
  /// menghentikan background & foreground tracking, serta mengakhiri/meninggalkan grup.
  Future<bool> completeAndEndTrip({
    required String? uid,
    required GroupModel? activeGroup,
    required bool isHost,
    required GroupProvider groupProvider,
    TripService? tripService,
  }) async {
    final effectiveTripService = tripService ?? TripService();
    final groupId = activeGroup?.id;
    bool tripSavedSuccessfully = false;

    // 1. Susun & simpan riwayat perjalanan sebelum menghentikan state tracking (BUG-01)
    if (uid != null && activeGroup != null) {
      try {
        final completedTrip = buildCompletedTripHistory(
          groupName: activeGroup.name,
          rawDestination: activeGroup.destination,
          groupType: activeGroup.type,
          isHost: isHost,
          fallbackMemberCount: activeGroup.memberCount,
          groupCreatedAt: activeGroup.createdAt,
        );
        await effectiveTripService.saveTrip(uid: uid, trip: completedTrip);
        tripSavedSuccessfully = true;
      } catch (e) {
        debugPrint('Error saving trip history on finish: $e');
      }
    }

    // 2. Siarkan event group_ended jika Host, agar semua anggota langsung terinfo
    if (isHost && groupId != null) {
      try {
        await broadcastGroupEnded(groupId);
      } catch (e) {
        debugPrint('Error broadcasting group_ended: $e');
      }
    }

    // 3. Hentikan tracking lokasi
    await stopTracking(groupId: groupId, uid: uid);

    // 4. Akhiri grup (jika Host) atau keluar grup (jika Member)
    if (uid != null && groupId != null) {
      if (isHost) {
        await groupProvider.endGroup();
      } else {
        await groupProvider.leaveGroup(uid: uid);
      }
    }

    return tripSavedSuccessfully;
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
            if (!_isGhostMode) {
              await _locationService.updateLocation(
                groupId: groupId,
                uid: uid,
                name: userName,
                lat: lastKnown.latitude,
                lng: lastKnown.longitude,
                status: _currentMemberStatus,
              );
            }
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

        // Throttling broadcast WebSocket (PERF-02):
        // Kirim WebSocket jika:
        // 1. Fix GPS pertama kali
        // 2. Status darurat SOS (harus instan tanpa delay)
        // 3. Sudah lewat >= 3 detik sejak broadcast terakhir
        // 4. Atau telah berpindah >= 50 meter sejak broadcast terakhir
        final now = DateTime.now();
        final isSOS = _currentMemberStatus == 'sos';
        final timeSinceLast = _lastBroadcastTime == null
            ? const Duration(seconds: 999)
            : now.difference(_lastBroadcastTime!);
        final distSinceLast = _lastBroadcastPosition == null
            ? 999.0
            : HaversineUtils.distanceInMeters(
                _lastBroadcastPosition!.latitude,
                _lastBroadcastPosition!.longitude,
                pos.latitude,
                pos.longitude,
              );

        final shouldBroadcast = isFirstFix ||
            isSOS ||
            timeSinceLast.inMilliseconds >= 3000 ||
            distSinceLast >= 50.0;

        if (shouldBroadcast) {
          _lastBroadcastTime = now;
          _lastBroadcastPosition = pos;
          if (!_isGhostMode) {
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
          }
        }
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
    _currentGroupId = null;
    _currentUserName = null;
    _backgroundPositionSubscription?.cancel();
    _backgroundPositionSubscription = null;
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
    _lastBroadcastTime = null;
    _lastBroadcastPosition = null;
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
      _lastBroadcastTime = DateTime.now();
      _lastBroadcastPosition = pos;
      if (!_isGhostMode) {
        await _locationService.updateLocation(
          groupId: groupId,
          uid: uid,
          name: name,
          lat: pos.latitude,
          lng: pos.longitude,
          status: _currentMemberStatus,
        );
      }
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleState(state);
  }

  @visibleForTesting
  void handleAppLifecycleState(AppLifecycleState state) {
    if (!_isTracking) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_isAppInForeground) {
        _isAppInForeground = false;
        _onEnterBackground();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isAppInForeground) {
        _isAppInForeground = true;
        _onEnterForeground();
      }
    }
  }

  void _onEnterBackground() {
    debugPrint('LocationProvider: transitioning to BACKGROUND mode');
    // 1. Hentikan foreground position stream untuk menghemat baterai & menghindari double GPS lock
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // 2. Aktifkan timer periodik di background isolate
    if (!kIsWeb) {
      unawaited(BackgroundLocationService.resumeTracking());
    }
  }

  void _onEnterForeground() {
    debugPrint('LocationProvider: transitioning to FOREGROUND mode');
    // 1. Hentikan timer periodik di background isolate
    if (!kIsWeb) {
      unawaited(BackgroundLocationService.pauseTracking());
    }

    // 2. Ambil koordinat terbaru & restart foreground stream seketika
    final gid = _currentGroupId;
    final uid = _currentUid;
    final name = _currentUserName;
    if (gid != null && uid != null && name != null) {
      unawaited(_acquireAndBroadcastPosition(groupId: gid, uid: uid, userName: name));
      _startForegroundPositionStream(groupId: gid, uid: uid, userName: name);
    }
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      debugPrint('WidgetsBindingObserver dispose warning: $e');
    }
    _backgroundPositionSubscription?.cancel();
    _backgroundPositionSubscription = null;
    _stopTokenSync();
    stopListening();
    super.dispose();
  }
}
