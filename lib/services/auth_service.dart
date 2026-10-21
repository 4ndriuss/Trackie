// File: auth_service.dart
// Service untuk menangani autentikasi pengguna menggunakan Supabase Auth
// dan menyimpan/mengambil data profil dari tabel PostgreSQL 'profiles'.
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../supabase_config.dart';

/// Extension untuk menjaga kompatibilitas API `User` dari Firebase ke Supabase
extension SupabaseUserExtension on User {
  String get uid => id;
  String? get displayName =>
      userMetadata?['name'] as String? ?? userMetadata?['full_name'] as String?;
  String? get photoURL =>
      userMetadata?['avatar_url'] as String? ?? userMetadata?['photo_url'] as String?;

  Future<void> updateDisplayName(String name) async {
    await SupabaseConfig.client.auth.updateUser(UserAttributes(data: {'name': name}));
  }
}

/// [AuthService] menyediakan semua operasi terkait autentikasi dan profil pengguna.
class AuthService {
  final SupabaseClient? _injectedClient;

  AuthService({SupabaseClient? supabaseClient}) : _injectedClient = supabaseClient;

  SupabaseClient get _supabase => _injectedClient ?? SupabaseConfig.client;

  static const int _maxAvatarBytes = 5 * 1024 * 1024; // 5 MB
  static const Map<String, String> _allowedImageMimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// Stream perubahan status autentikasi.
  Stream<User?> get authStateChanges => _supabase.auth.onAuthStateChange
      .map((event) => event.session?.user ?? _supabase.auth.currentUser);

  /// Mendapatkan user yang sedang login.
  User? get currentUser => _supabase.auth.currentUser;

  /// Login dengan email dan password.
  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user != null) {
      await _ensureUserProfileExists(response.user!);
    }
    return response;
  }

  /// Mendaftarkan user baru (membuat akun Supabase Auth + profil di database).
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    String vehicle = '',
    String? phone,
    DateTime? birthDate,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name.trim(),
        'vehicle': vehicle.trim(),
        'phone': phone?.trim(),
        // Format YYYY-MM-DD agar bisa di-cast ke DATE oleh trigger database
        if (birthDate != null)
          'birth_date': birthDate.toIso8601String().split('T').first,
      },
    );

    if (response.user != null && response.session != null) {
      final user = UserModel(
        uid: response.user!.id,
        name: name.trim(),
        email: email.trim(),
        vehicle: vehicle.trim(),
        phone: phone?.trim(),
        birthDate: birthDate,
        createdAt: DateTime.now(),
      );

      // Simpan/sinkronkan ke tabel 'profiles' jika sesi langsung aktif
      try {
        await _supabase.from('profiles').upsert(user.toSupabase());
      } catch (e) {
        debugPrint('Warning saving profile to database: $e');
      }
    }

    return response;
  }

  /// Pastikan dokumen profil pengguna ada di database setelah login.
  Future<void> _ensureUserProfileExists(User supabaseUser) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (existing == null) {
        final meta = supabaseUser.userMetadata ?? const <String, dynamic>{};
        final name = supabaseUser.displayName ??
            meta['full_name'] as String? ??
            'User';
        final birthRaw = meta['birth_date'] as String?;
        final birthDate = birthRaw != null ? DateTime.tryParse(birthRaw) : null;
        final user = UserModel(
          uid: supabaseUser.id,
          name: name,
          email: supabaseUser.email ?? '',
          vehicle: (meta['vehicle'] as String?) ?? '',
          phone: (meta['phone'] as String?) ?? supabaseUser.phone,
          birthDate: birthDate,
          photoUrl: supabaseUser.photoURL,
          createdAt: DateTime.now(),
        );
        await _supabase.from('profiles').upsert(user.toSupabase());
      }
    } catch (e) {
      debugPrint('Error ensuring user profile exists: $e');
    }
  }

  /// Login dengan Google
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: SupabaseConfig.googleWebClientId.isEmpty
            ? null
            : SupabaseConfig.googleWebClientId,
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // Batal login

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Gagal mendapatkan ID Token dari Google Sign-In');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        await _ensureUserProfileExists(response.user!);
      }
      return response;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Login dengan Facebook (DEP-03: Dormant - belum dikonfigurasi resmi dengan Meta App ID)
  Future<AuthResponse?> signInWithFacebook() async {
    throw const AuthException(
      'Facebook Login belum dikonfigurasi pada perangkat ini.',
    );
  }

  /// Keluar dari akun.
  Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  /// Mengirim email reset password.
  Future<void> resetPassword(String email) {
    return _supabase.auth.resetPasswordForEmail(email.trim());
  }

  /// Mengambil profil pengguna dari database Supabase.
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data != null) {
        return UserModel.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
    return null;
  }

  /// Memperbarui data profil pengguna di database Supabase.
  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? vehicle,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (vehicle != null) updates['vehicle'] = vehicle.trim();
    if (photoUrl != null) updates['avatar_url'] = photoUrl;

    if (updates.isNotEmpty) {
      await _supabase.from('profiles').update(updates).eq('id', uid);
    }
  }

  /// Mengunggah file foto profil ke Supabase Storage (bucket 'avatars').
  Future<String?> uploadProfilePicture(
    String uid,
    Uint8List fileBytes,
    String ext,
  ) async {
    try {
      if (fileBytes.isEmpty || fileBytes.length > _maxAvatarBytes) {
        throw Exception('Ukuran foto profil maksimal 5 MB.');
      }

      final sanitizedExt = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final mimeType = _allowedImageMimeTypes[sanitizedExt];
      if (mimeType == null) {
        throw Exception('Format file tidak didukung. Gunakan JPG, PNG, atau WEBP.');
      }

      final path = '$uid/avatar.$sanitizedExt';
      await _supabase.storage.from('avatars').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      final cacheBustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Perbarui kolom avatar_url di profil pengguna
      await updateUserProfile(uid, photoUrl: cacheBustedUrl);

      return cacheBustedUrl;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Menghapus akun pengguna secara permanen:
  /// 1. Hapus file avatar di Storage
  /// 2. Panggil RPC `delete_my_account` (menghapus auth.users -> cascade ke
  ///    profiles & trip_history). Lihat supabase_security.sql.
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final uid = user.id;

    try {
      final files = await _supabase.storage.from('avatars').list(path: uid);
      if (files.isNotEmpty) {
        await _supabase.storage
            .from('avatars')
            .remove(files.map((f) => '$uid/${f.name}').toList());
      }
    } catch (e) {
      debugPrint('Warning removing avatar files: $e');
    }

    await _supabase.rpc('delete_my_account');
    await _supabase.auth.signOut();
  }
}
