// File: group_service.dart
// Service untuk mengelola grup/perjalanan menggunakan database Supabase (PostgreSQL).
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import '../supabase_config.dart';

/// [GroupService] menyediakan operasi CRUD untuk tabel 'groups' di Supabase.
class GroupService {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Membuat kode undangan unik secara kriptografis dengan format TRG-XXXXXX.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    return 'TRG-$code';
  }

  /// Membuat grup baru dan mengembalikan [GroupModel].
  /// Keunikan kode undangan dijamin oleh constraint UNIQUE di database;
  /// jika terjadi bentrok (sangat jarang), coba lagi dengan kode baru.
  Future<GroupModel> createGroup({
    required String name,
    required String type,
    required String destination,
    required String hostUid,
  }) async {
    PostgrestException? lastError;
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        final data = await _supabase.from('groups').insert({
          'name': name.trim(),
          'type': type.trim().toLowerCase(),
          'destination': destination.trim(),
          'invite_code': _generateInviteCode(),
          'host_uid': hostUid,
          'member_uids': [hostUid],
          'status': 'active',
        }).select().single();

        return GroupModel.fromMap(data);
      } on PostgrestException catch (e) {
        // 23505 = unique_violation (kode undangan sudah dipakai)
        if (e.code != '23505') rethrow;
        lastError = e;
      }
    }
    throw lastError!;
  }

  /// Bergabung ke grup yang sudah ada menggunakan kode undangan.
  /// Dilakukan via RPC `join_group` (atomik & divalidasi di server).
  /// Mengembalikan [GroupModel] jika berhasil, null jika kode tidak ditemukan.
  Future<GroupModel?> joinGroup({
    required String inviteCode,
    required String uid,
  }) async {
    final normalizedCode = inviteCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;

    final result = await _supabase.rpc(
      'join_group',
      params: {'p_invite_code': normalizedCode},
    );

    final rows = (result as List?) ?? const [];
    if (rows.isEmpty) return null;
    return GroupModel.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  /// Keluar dari grup via RPC `leave_group`.
  /// Jika anggota terakhir, grup otomatis diakhiri.
  /// Jika host keluar tetapi masih ada anggota lain, kepemilikan grup dialihkan.
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    await _supabase.rpc('leave_group', params: {'p_group_id': groupId});
  }

  /// Mengakhiri grup (hanya host) via RPC `end_group`.
  Future<void> endGroup(String groupId) async {
    await _supabase.rpc('end_group', params: {'p_group_id': groupId});
  }

  /// Mengambil data grup berdasarkan ID.
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final data = await _supabase
          .from('groups')
          .select()
          .eq('id', groupId)
          .maybeSingle();

      if (data != null) {
        return GroupModel.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error getting group: $e');
    }
    return null;
  }

  /// Mencari grup aktif yang diikuti oleh user tertentu.
  Future<GroupModel?> getActiveGroupForUser(String uid) async {
    try {
      final data = await _supabase
          .from('groups')
          .select()
          .contains('member_uids', [uid])
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        return GroupModel.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error getting active group for user: $e');
    }
    return null;
  }

  /// Stream data grup secara real-time.
  Stream<GroupModel?> streamGroup(String groupId) {
    return _supabase
        .from('groups')
        .stream(primaryKey: ['id'])
        .eq('id', groupId)
        .map((list) => list.isNotEmpty ? GroupModel.fromMap(list.first) : null);
  }
}
