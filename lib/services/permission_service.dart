// File: permission_service.dart
// Service untuk menangani izin lokasi secara bertahap.
// Android 12+ memerlukan izin lokasi "While Using" terlebih dahulu,
// baru kemudian bisa meminta "Always Allow" (background location).
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// [PermissionService] mengelola request izin lokasi secara bertahap
/// sesuai kebijakan Android 12+ dan iOS.
class PermissionService {
  /// Minta izin lokasi dasar (foreground / "While Using").
  /// Mengembalikan true jika izin diberikan.
  static Future<bool> requestLocationPermission() async {
    // Cek apakah layanan lokasi aktif
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Cek status izin saat ini
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
  /// Mengembalikan true jika izin diberikan.
  static Future<bool> requestBackgroundLocationPermission() async {
    // Pastikan foreground permission sudah diberikan terlebih dahulu
    final foregroundGranted = await requestLocationPermission();
    if (!foregroundGranted) return false;

    // Minta background location permission
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Minta izin notifikasi (Android 13+).
  /// Mengembalikan true jika izin diberikan.
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Minta semua izin yang dibutuhkan untuk tracking.
  /// Mengembalikan true jika semua izin penting diberikan.
  static Future<bool> requestAllTrackingPermissions() async {
    // 1. Izin lokasi foreground
    final locationGranted = await requestLocationPermission();
    if (!locationGranted) return false;

    // 2. Izin notifikasi (untuk foreground service notification)
    await requestNotificationPermission();

    // 3. Izin lokasi background
    final backgroundGranted = await requestBackgroundLocationPermission();

    return backgroundGranted;
  }

  /// Tampilkan dialog jika izin ditolak permanen.
  /// Arahkan user ke Settings app.
  static Future<void> showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin Lokasi Diperlukan'),
        content: const Text(
          'Trackie membutuhkan akses lokasi "Selalu Izinkan" agar posisi Anda '
          'tetap terlihat oleh anggota grup saat HP dikunci.\n\n'
          'Buka Pengaturan → Izin → Lokasi → Izinkan Selalu.',
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
