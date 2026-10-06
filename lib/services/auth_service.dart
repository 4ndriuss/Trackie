// File: auth_service.dart
// Service untuk menangani autentikasi pengguna menggunakan Firebase Auth
// dan menyimpan/mengambil data profil dari Firestore.
// ...
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../models/user_model.dart';

/// [AuthService] menyediakan semua operasi terkait autentikasi dan profil pengguna.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream perubahan status autentikasi.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Mendapatkan user yang sedang login.
  User? get currentUser => _auth.currentUser;

  /// Login dengan email dan password.
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Mendaftarkan user baru (membuat akun Auth + dokumen profil di Firestore).
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    String vehicle = '',
    String? phone,
    DateTime? birthDate,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      final user = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email,
        vehicle: vehicle,
        phone: phone,
        birthDate: birthDate,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toFirestore());
    }

    return credential;
  }

  /// Login dengan Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Batal login

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // Jika user baru, buat profil di Firestore
      if (userCredential.user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        final user = UserModel(
          uid: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'User',
          email: userCredential.user!.email ?? '',
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(user.toFirestore());
      }
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Login dengan Facebook
  Future<UserCredential?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
        final userCredential = await _auth.signInWithCredential(credential);
        
        // Jika user baru, buat profil di Firestore
        if (userCredential.user != null && userCredential.additionalUserInfo?.isNewUser == true) {
          final user = UserModel(
            uid: userCredential.user!.uid,
            name: userCredential.user!.displayName ?? 'User',
            email: userCredential.user!.email ?? '',
            createdAt: DateTime.now(),
          );

          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(user.toFirestore());
        }
        return userCredential;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error signing in with Facebook: $e');
      rethrow;
    }
  }

  /// Keluar dari akun.
  Future<void> signOut() {
    return _auth.signOut();
  }

  /// Mengirim email reset password.
  Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Mengambil profil pengguna dari Firestore.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  /// Memperbarui data profil pengguna di Firestore.
  Future<void> updateUserProfile(String uid, {String? name, String? vehicle, String? photoUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (vehicle != null) updates['vehicle'] = vehicle;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  /// Mengunggah file foto profil ke Firebase Storage dan mengembalikan URL-nya.
  Future<String?> uploadProfilePicture(String uid, Uint8List fileBytes, String ext) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final profileRef = storageRef.child('profiles/$uid/avatar.$ext');
      
      final uploadTask = await profileRef.putData(fileBytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Update the user's document with the new photoUrl
      await updateUserProfile(uid, photoUrl: downloadUrl);
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }
}
