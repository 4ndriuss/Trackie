// File: location_provider.dart
// Provider untuk mengelola state lokasi real-time anggota grup.
// Mengintegrasikan LocationService (Supabase Realtime Broadcast), BackgroundLocationService
// (Foreground Service), dan PermissionService (izin lokasi).
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/background_location_service.dart';
import '../services/permission_service.dart';
import '../models/location_model.dart';

/// [LocationProvider] mengelola:
/// - Stream lokasi anggota grup dari Supabase Realtime Broadcast
/// - Background tracking via Foreground Service
/// - Permission handling untuk lokasi
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  List<MemberLocation> _members = [];
  StreamSubscription? _locationSubscription;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _permissionsGranted = false;
  String? _error;

  List<MemberLocation> get members => _members;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get permissionsGranted => _permissionsGranted;
  String? get error => _error;

  /// Minta semua izin yang diperlukan untuk tracking.
  /// Mengembalikan true jika semua izin diberikan.
  Future<bool> requestPermissions() async {
    _permissionsGranted = await PermissionService.requestAllTrackingPermissions();
    notifyListeners();
    return _permissionsGranted;
  }

  /// Mulai mendengarkan perubahan lokasi seluruh anggota grup dari RTDB
  /// DAN memulai background location tracking.
  Future<void> startTracking({
    required String groupId,
    required String uid,
    required String userName,
    String? tripName,
  }) async {
    // 1. Mulai listen lokasi anggota dari RTDB
    stopListening();
    _isTracking = true;
    _error = null;
    _locationSubscription = _locationService
        .streamGroupLocations(groupId)
        .listen((locations) {
      _members = locations;
      notifyListeners();
    }, onError: (e) {
      _error = 'Gagal menerima lokasi anggota.';
      debugPrint('Error streaming locations: $e');
      notifyListeners();
    });

    // 2. Broadcast posisi awal segera agar muncul di peta tanpa menunggu 5 detik
    unawaited(broadcastLocation(groupId: groupId, uid: uid, name: userName));

    // 3. Mulai background tracking (Foreground Service) untuk Android/iOS
    if (!kIsWeb) {
      try {
        await BackgroundLocationService.startTracking(
          groupId: groupId,
          uid: uid,
          userName: userName,
          tripName: tripName,
        );
      } catch (e) {
        debugPrint('Error starting background service: $e');
      }
    }

    notifyListeners();
  }

  /// Hentikan semua tracking (stream + background service).
  Future<void> stopTracking({
    String? groupId,
    String? uid,
  }) async {
    // Set offline di RTDB sebelum stop
    if (groupId != null && uid != null) {
      try {
        await _locationService.setOffline(groupId: groupId, uid: uid);
      } catch (e) {
        debugPrint('Error setting offline: $e');
      }
    }

    // Stop background service
    if (!kIsWeb) {
      try {
        await BackgroundLocationService.stopTracking();
      } catch (e) {
        debugPrint('Error stopping background service: $e');
      }
    }

    // Stop stream listener
    stopListening();

    // Tutup channel Realtime agar tidak terus menerima lokasi grup lama
    if (groupId != null) {
      await _locationService.cleanupGroupLocations(groupId);
    }
  }

  /// Hanya stop stream listener (tanpa stop background service).
  void stopListening() {
    _isTracking = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _members = [];
    notifyListeners();
  }

  /// Broadcast lokasi sendiri sekali (untuk update manual / initial).
  Future<void> broadcastLocation({
    required String groupId,
    required String uid,
    required String name,
  }) async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      await _locationService.updateLocation(
        groupId: groupId,
        uid: uid,
        name: name,
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
      );
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
    stopListening();
    super.dispose();
  }
}
