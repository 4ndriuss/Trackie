// File: background_location_service.dart
// Service untuk mengelola tracking lokasi di background menggunakan
// Foreground Service (Android) dan Background Modes (iOS).
// Memastikan lokasi tetap terkirim meskipun HP dikunci atau app di-background.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';

/// [BackgroundLocationService] mengelola lifecycle background tracking.
/// Saat tracking dimulai, service ini:
/// 1. Menampilkan notifikasi persistent ("Tracking aktif...")
/// 2. Mengambil koordinat GPS secara berkala
/// 3. Mengirim lokasi ke Firebase Realtime Database
class BackgroundLocationService {
  static const String _notificationChannelId = 'trackie_tracking';
  static const String _notificationChannelName = 'Location Tracking';

  /// Inisialisasi background service. Panggil sekali saat app dimulai.
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Setup notification channel untuk Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Notifikasi saat Trackie sedang melacak lokasi Anda',
      importance: Importance.low, // Low agar tidak bunyi terus
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Konfigurasi background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false, // Jangan auto-start, akan dimulai manual saat join grup
        isForegroundMode: true, // Foreground service dengan notifikasi
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'Trackie',
        initialNotificationContent: 'Mempersiapkan tracking...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Mulai background tracking.
  /// Panggil saat user masuk ke grup/mulai perjalanan.
  static Future<void> startTracking({
    required String groupId,
    required String uid,
    required String userName,
    String? tripName,
  }) async {
    final service = FlutterBackgroundService();
    await service.startService();

    // Kirim data grup ke background isolate
    service.invoke('startTracking', {
      'groupId': groupId,
      'uid': uid,
      'userName': userName,
      'tripName': tripName ?? 'Perjalanan',
    });
  }

  /// Perbarui status anggota di background isolate (misal: 'sos' atau 'online')
  /// agar ping periodik tidak menimpa status SOS.
  static void setStatus(String status) {
    final service = FlutterBackgroundService();
    service.invoke('setStatus', {'status': status});
  }

  /// Hentikan background tracking.
  /// Panggil saat user keluar dari grup.
  static Future<void> stopTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stopTracking');
  }

  /// Update notifikasi (misal: ganti jumlah anggota).
  static void updateNotification(String content) {
    final service = FlutterBackgroundService();
    service.invoke('updateNotification', {'content': content});
  }
}

// ==========================================
// BACKGROUND ISOLATE HANDLERS
// Kode di bawah ini berjalan di isolate terpisah
// (bukan di main UI thread)
// ==========================================

/// Handler utama yang berjalan di background isolate.
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Inisialisasi Firebase di background isolate
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase already initialized or error: $e');
  }

  final rtdb = FirebaseDatabase.instance;

  String? groupId;
  String? uid;
  String? userName;
  String currentStatus = 'online';
  Timer? locationTimer;

  // Listen perubahan status (misal: SOS)
  service.on('setStatus').listen((event) {
    final newStatus = event?['status'] as String?;
    if (newStatus != null && newStatus.isNotEmpty) {
      currentStatus = newStatus;
    }
  });

  // Listen perintah dari main isolate
  service.on('startTracking').listen((event) {
    groupId = event?['groupId'];
    uid = event?['uid'];
    userName = event?['userName'];
    currentStatus = 'online';
    final tripName = event?['tripName'] ?? 'Perjalanan';

    // Update notifikasi
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: '📍 Trackie — Tracking Aktif',
        content: '$tripName sedang berlangsung',
      );
    }

    // Mulai kirim lokasi setiap 5 detik
    locationTimer?.cancel();
    locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (groupId == null || uid == null) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Minimum 10 meter perpindahan
          ),
        );

        // Kirim ke Firebase Realtime Database dengan mempertahankan currentStatus
        await rtdb.ref('active_locations/$groupId/$uid').set({
          'uid': uid,
          'name': userName,
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': ServerValue.timestamp,
          'status': currentStatus,
        });
      } catch (e) {
        debugPrint('Background location error: $e');
      }
    });
  });

  // Listen perintah stop
  service.on('stopTracking').listen((event) async {
    locationTimer?.cancel();
    locationTimer = null;

    // Set status offline sebelum stop
    if (groupId != null && uid != null) {
      try {
        await rtdb.ref('active_locations/$groupId/$uid').update({
          'status': 'offline',
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('Failed to update offline status in background: $e');
      }
    }

    service.stopSelf();
  });

  // Listen update notifikasi
  service.on('updateNotification').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: '📍 Trackie — Tracking Aktif',
        content: event?['content'] ?? '',
      );
    }
  });
}

/// Handler untuk iOS background execution.
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
