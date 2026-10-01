import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_history_model.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Save a completed trip to the user's trip history
  // Collection: users/{uid}/trip_history
  Future<void> saveTrip({required String uid, required TripHistoryModel trip}) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('trip_history')
        .doc(trip.id)
        .set(trip.toMap());
  }
  
  // Get all trip history for a user, ordered by startedAt descending
  Future<List<TripHistoryModel>> getTripHistory(String uid) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('trip_history')
        .orderBy('startedAt', descending: true)
        .get();
        
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TripHistoryModel.fromMap(data);
    }).toList();
  }
  
  // Stream trip history
  Stream<List<TripHistoryModel>> streamTripHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('trip_history')
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TripHistoryModel.fromMap(data);
      }).toList();
    });
  }
  
  // Update trip journal note and rating
  Future<void> updateTripJournal({required String uid, required String tripId, String? note, double? rating}) async {
    Map<String, dynamic> updates = {};
    if (note != null) updates['note'] = note;
    if (rating != null) updates['rating'] = rating;
    
    if (updates.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('trip_history')
          .doc(tripId)
          .update(updates);
    }
  }
}
