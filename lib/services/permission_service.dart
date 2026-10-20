// File: permission_service.dart
// Service untuk menangani izin lokasi secara bertahap.
// Android 12+ memerlukan izin lokasi "While Using" terlebih dahulu,
// baru kemudian bisa meminta "Always Allow" (background location).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// [PermissionService] mengelola request izin lokasi secara bertahap
/// sesuai kebijakan Android 12+ dan iOS.
class PermissionService {
  /// Minta izin lokasi dasar (foreground / "While Using").
  /// Mengembalikan true jika izin diberikan.
  static Future<bool> requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Minta izin lokasi background ("Always Allow").
  /// Harus dipanggil SETELAH izin foreground diberikan.
  static Future<bool> requestBackgroundLocationPermission() async {
    final foregroundGranted = await requestLocationPermission();
    if (!foregroundGranted) return false;
    if (kIsWeb) return true;

    try {
      final status = await Permission.locationAlways.request();
      return status.isGranted;
    } catch (_) {
      return foregroundGranted;
    }
  }

  /// Minta izin notifikasi (Android 13+).
  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Minta semua izin yang dibutuhkan untuk tracking.
  /// Mengembalikan true selama izin lokasi foreground ("Saat aplikasi digunakan" / "Selalu") diberikan.
  static Future<bool> requestAllTrackingPermissions() async {
    // 1. Izin lokasi foreground (wajib untuk GPS & rute)
    final locationGranted = await requestLocationPermission();
    if (!locationGranted) return false;

    // 2. Izin notifikasi & background (opsional untuk foreground service di Android/iOS)
    if (!kIsWeb) {
      await requestNotificationPermission();
      await requestBackgroundLocationPermission();
    }

    return true;
  }

  /// Tampilkan dialog jika izin ditolak permanen.
  /// Arahkan user ke Settings app.
  static Future<void> showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin Lokasi Diperlukan'),
        content: const Text(
          'Trackie membutuhkan akses lokasi agar posisi Anda dan rute perjalanan '
          'dapat ditampilkan secara akurat dari daerah Anda saat ini.\n\n'
          'Buka Pengaturan → Izin → Lokasi → Izinkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('NANTI'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('BUKA PENGATURAN'),
          ),
        ],
      ),
    );
  }
}
