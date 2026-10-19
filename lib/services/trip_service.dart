import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_history_model.dart';
import '../supabase_config.dart';

class TripService {
  SupabaseClient get _supabase => SupabaseConfig.client;

  // Save a completed trip to the user's trip history
  // Table: public.trip_history
  Future<void> saveTrip({required String uid, required TripHistoryModel trip}) async {
    try {
      final map = trip.toSupabase();
      map['user_id'] = uid;
      await _supabase.from('trip_history').upsert(map);
    } catch (e) {
      debugPrint('Error saving trip: $e');
      rethrow;
    }
  }

  // Get all trip history for a user, ordered by started_at descending
  Future<List<TripHistoryModel>> getTripHistory(String uid) async {
    try {
      final data = await _supabase
          .from('trip_history')
          .select()
          .eq('user_id', uid)
          .order('started_at', ascending: false);

      return (data as List)
          .map((item) => TripHistoryModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting trip history: $e');
      return [];
    }
  }

  // Stream trip history in real-time
  Stream<List<TripHistoryModel>> streamTripHistory(String uid) {
    return _supabase
        .from('trip_history')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('started_at', ascending: false)
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
