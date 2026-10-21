// File: lib/services/secure_local_storage.dart
// SEC-01: Penyimpanan sesi JWT Supabase terenkripsi menggunakan Android Keystore & iOS Keychain
// menggantikan SharedPreferences bawaan yang menyimpan token plaintext.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementasi [LocalStorage] aman menggunakan [FlutterSecureStorage] (Keystore/Keychain).
/// Mendukung migrasi mulus dari token sesi lama di [SharedPreferences] agar sesi pengguna tidak hilang.
class SecureLocalStorage extends LocalStorage {
  final String persistSessionKey;
  final FlutterSecureStorage secureStorage;

  const SecureLocalStorage({
    this.persistSessionKey = 'supabase_auth_token',
    this.secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  });

  @override
  Future<void> initialize() async {
    // Pada platform Web, gunakan fallback SharedPreferences / LocalStorage bawaan
    if (kIsWeb) return;

    try {
      // Migrasi aman dari SharedPreferences jika terdapat sesi lama yang belum terenkripsi
      final prefs = await SharedPreferences.getInstance();
      const legacyKey = 'supabase_persist_session_key';
      final legacySession = prefs.getString(legacyKey) ?? prefs.getString(persistSessionKey);

      if (legacySession != null && legacySession.isNotEmpty) {
        final existingSecure = await secureStorage.read(key: persistSessionKey);
        if (existingSecure == null || existingSecure.isEmpty) {
          await secureStorage.write(key: persistSessionKey, value: legacySession);
        }
        // Hapus token plaintext dari SharedPreferences setelah diamankan ke Keystore
        await prefs.remove(legacyKey);
        await prefs.remove(persistSessionKey);
        debugPrint('SecureLocalStorage: Sesi pengguna lama berhasil dimigrasikan ke Keystore/Keychain.');
      }
    } catch (e) {
      debugPrint('Warning during secure storage migration: $e');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(persistSessionKey);
    }
    final token = await secureStorage.read(key: persistSessionKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(persistSessionKey);
    }
    return await secureStorage.read(key: persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(persistSessionKey);
      return;
    }
    await secureStorage.delete(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(persistSessionKey, persistSessionString);
      return;
    }
    await secureStorage.write(key: persistSessionKey, value: persistSessionString);
  }
}
