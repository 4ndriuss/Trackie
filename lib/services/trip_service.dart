import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_history_model.dart';
import '../supabase_config.dart';

class TripService {
  final SupabaseClient? _injectedClient;

  TripService({SupabaseClient? supabaseClient}) : _injectedClient = supabaseClient;

  SupabaseClient get _supabase => _injectedClient ?? SupabaseConfig.client;

  static String _pendingKey(String uid) => 'pending_trips_$uid';

  // Save a completed trip to the user's trip history
  // Table: public.trip_history
  Future<void> saveTrip({required String uid, required TripHistoryModel trip}) async {
    try {
      final map = trip.toSupabase();
      map['user_id'] = uid;
      await _supabase.from('trip_history').upsert(map);
    } catch (e) {
      debugPrint('Error saving trip to Supabase: $e');
      // Otomatis amankan data jejak rute ke antrean lokal agar tidak hilang (BUG-01)
      await saveTripLocally(uid, trip);
      rethrow;
    }
  }

  /// Menyimpan riwayat perjalanan ke cache lokal SharedPreferences saat offline / gagal koneksi.
  Future<void> saveTripLocally(String uid, TripHistoryModel trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingKey(uid);
      final list = prefs.getStringList(key) ?? [];
      final jsonStr = jsonEncode(trip.toMap());
      if (!list.contains(jsonStr)) {
        list.add(jsonStr);
        await prefs.setStringList(key, list);
        debugPrint('Trip successfully saved locally to offline queue: ${trip.id}');
      }
    } catch (e) {
      debugPrint('Error saving trip locally: $e');
    }
  }

  /// Mengambil daftar riwayat perjalanan tertunda dari penyimpanan lokal.
  Future<List<TripHistoryModel>> getPendingLocalTrips(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingKey(uid)) ?? [];
      return list.map((item) {
        final map = jsonDecode(item) as Map<String, dynamic>;
        return TripHistoryModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('Error reading pending local trips: $e');
      return [];
    }
  }

  /// Menyinkronkan seluruh riwayat perjalanan tertunda ke cloud jika koneksi internet telah pulih.
  Future<int> syncPendingTrips(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingKey(uid);
      final list = prefs.getStringList(key) ?? [];
      if (list.isEmpty) return 0;

      int syncedCount = 0;
      final remaining = <String>[];

      for (final item in list) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          final trip = TripHistoryModel.fromMap(map);
          final uploadMap = trip.toSupabase()..['user_id'] = uid;
          await _supabase.from('trip_history').upsert(uploadMap);
          syncedCount++;
        } catch (e) {
          debugPrint('Failed to sync one pending trip, keeping in queue: $e');
          remaining.add(item);
        }
      }

      await prefs.setStringList(key, remaining);
      return syncedCount;
    } catch (e) {
      debugPrint('Error syncing pending trips: $e');
      return 0;
    }
  }

  /// Kolom ringkasan riwayat perjalanan tanpa array JSONB route_path ratusan KB (PERF-06).
  static const String summaryColumns =
      'id, user_id, group_name, group_type, distance_km, duration, member_count, started_at, ended_at, journal_note, rating';

  /// Mengambil daftar riwayat perjalanan pengguna dengan paginasi dan opsi eksklusi route_path (PERF-06 / PERF-16).
  Future<List<TripHistoryModel>> getTripHistory(
    String uid, {
    int limit = 50,
    int offset = 0,
    bool includeRoutePath = false,
  }) async {
    // Sinkronkan data offline tertunda jika koneksi pulih
    try {
      await syncPendingTrips(uid);
    } catch (e) {
      debugPrint('Info syncPendingTrips: $e');
    }

    try {
      final columns = includeRoutePath ? '*' : summaryColumns;
      final data = await _supabase
          .from('trip_history')
          .select(columns)
          .eq('user_id', uid)
          .order('started_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((item) => TripHistoryModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting trip history from remote: $e');
      // Jika offline, kembalikan data riwayat lokal tertunda
      return await getPendingLocalTrips(uid);
    }
  }

  /// Mengambil detail riwayat perjalanan lengkap termasuk route_path untuk visualisasi rute detail (PERF-06).
  Future<TripHistoryModel?> getTripDetail({
    required String uid,
    required String tripId,
  }) async {
    try {
      final data = await _supabase
          .from('trip_history')
          .select('*')
          .eq('id', tripId)
          .eq('user_id', uid)
          .maybeSingle();

      if (data == null) return null;
      return TripHistoryModel.fromMap(data);
    } catch (e) {
      debugPrint('Error getting trip detail: $e');
      return null;
    }
  }

  // Stream trip history in real-time dengan limit default 50 (PERF-16)
  Stream<List<TripHistoryModel>> streamTripHistory(
    String uid, {
    int limit = 50,
  }) {
    return _supabase
        .from('trip_history')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('started_at', ascending: false)
        .limit(limit)
        .map((list) => list
            .map((item) => TripHistoryModel.fromMap(item))
            .toList());
  }

  // Update trip journal note and rating
  Future<void> updateTripJournal({
    required String uid,
    required String tripId,
    String? note,
    double? rating,
  }) async {
    final updates = <String, dynamic>{};
    if (note != null) updates['journal_note'] = note;
    if (rating != null) updates['rating'] = rating;

    if (updates.isNotEmpty) {
      await _supabase
          .from('trip_history')
          .update(updates)
          .eq('id', tripId)
          .eq('user_id', uid);
    }
  }
}
