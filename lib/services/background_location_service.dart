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
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import 'location_service.dart';

/// [BackgroundLocationService] mengelola lifecycle background tracking.
/// Saat tracking dimulai, service ini:
/// 1. Menampilkan notifikasi persistent ("Tracking aktif...")
/// 2. Mengambil koordinat GPS secara berkala
/// 3. Mengirim lokasi ke Supabase Realtime Broadcast (Zero DB Write)
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
    required String? accessToken,
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
      'accessToken': accessToken,
    });
  }

  /// Kirim access token terbaru ke background isolate.
  /// Wajib dipanggil setiap kali sesi di-refresh, karena private channel
  /// akan diputus oleh server ketika JWT kedaluwarsa.
  static void updateAccessToken(String accessToken) {
    final service = FlutterBackgroundService();
    service.invoke('updateToken', {'accessToken': accessToken});
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

  // Access token (JWT) user, dikirim dari main isolate. Background isolate
  // sengaja TIDAK memegang refresh token agar tidak terjadi rotasi ganda
  // yang bisa membuat Supabase mencabut sesi.
  String? accessToken;

  // Inisialisasi client Supabase untuk background isolate (terautentikasi)
  final supabase = SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.anonKey,
    accessToken: () async => accessToken,
  );

  String? groupId;
  String? uid;
  String? userName;
  String currentStatus = 'online';
  Timer? locationTimer;
  RealtimeChannel? trackingChannel;

  // Listen pembaruan token dari main isolate (setelah sesi di-refresh)
  service.on('updateToken').listen((event) async {
    final token = event?['accessToken'] as String?;
    if (token == null || token.isEmpty) return;
    accessToken = token;
    try {
      await supabase.realtime.setAuth(token);
    } catch (e) {
      debugPrint('Failed to update realtime auth in background: $e');
    }
  });

  // Listen perubahan status (misal: SOS)
  service.on('setStatus').listen((event) {
    final newStatus = event?['status'] as String?;
    if (newStatus != null && newStatus.isNotEmpty) {
      currentStatus = newStatus;
    }
  });

  // Listen perintah dari main isolate
  service.on('startTracking').listen((event) async {
    groupId = event?['groupId'];
    uid = event?['uid'];
    userName = event?['userName'];
    accessToken = (event?['accessToken'] as String?) ?? accessToken;
    currentStatus = 'online';
    final tripName = event?['tripName'] ?? 'Perjalanan';

    // Update notifikasi
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: '📍 Trackie — Tracking Aktif',
        content: '$tripName sedang berlangsung',
      );
    }

    if (groupId != null) {
      await trackingChannel?.unsubscribe();
      trackingChannel = null;

      if (accessToken == null) {
        // Private channel menolak koneksi anonim.
        debugPrint('Background tracking skipped: no access token');
      } else {
        await supabase.realtime.setAuth(accessToken);
        trackingChannel = supabase.channel(
          LocationService.trackingTopic(groupId!),
          opts: const RealtimeChannelConfig(private: true),
        );
        trackingChannel?.subscribe();
      }
    }

    // Mulai kirim lokasi setiap 5 detik
    locationTimer?.cancel();
    locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (groupId == null || uid == null || trackingChannel == null) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Minimum 10 meter perpindahan
          ),
        );

        // Kirim via Supabase Realtime Broadcast (Zero DB Cost)
        await trackingChannel?.sendBroadcastMessage(
          event: 'location_update',
          payload: {
            'uid': uid,
            'name': userName,
            'lat': position.latitude,
            'lng': position.longitude,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'status': currentStatus,
          },
        );
      } catch (e) {
        debugPrint('Background location error: $e');
      }
    });
  });

  // Listen perintah stop
  service.on('stopTracking').listen((event) async {
    locationTimer?.cancel();
    locationTimer = null;

    // Broadcast status offline sebelum stop
    if (groupId != null && uid != null && trackingChannel != null) {
      try {
        await trackingChannel?.sendBroadcastMessage(
          event: 'status_update',
          payload: {
            'uid': uid,
            'status': 'offline',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
        await trackingChannel?.unsubscribe();
        trackingChannel = null;
      } catch (e) {
        debugPrint('Failed to broadcast offline in background: $e');
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
