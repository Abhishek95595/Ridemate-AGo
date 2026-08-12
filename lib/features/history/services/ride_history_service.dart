import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ride_history_model.dart';

class RideHistoryService {
  RideHistoryService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _bookingsCollection {
    return _firestore.collection('bookings');
  }

  String get _currentUserId {
    final User? currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw Exception('User is not logged in.');
    }

    return currentUser.uid;
  }

  /// Returns every booking made by the currently logged-in passenger.
  Stream<List<RideHistoryModel>> getAllRideHistory() {
    try {
      final String passengerId = _currentUserId;

      return _bookingsCollection
          .where('passengerId', isEqualTo: passengerId)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<RideHistoryModel> rides = snapshot.docs.map((
              QueryDocumentSnapshot<Map<String, dynamic>> document,
            ) {
              return RideHistoryModel.fromFirestore(document);
            }).toList();

            rides.sort((RideHistoryModel first, RideHistoryModel second) {
              return second.bookedAt.compareTo(first.bookedAt);
            });

            return rides;
          });
    } catch (error) {
      return Stream<List<RideHistoryModel>>.error(error);
    }
  }

  /// Returns bookings whose status is upcoming.
  Stream<List<RideHistoryModel>> getUpcomingRides() {
    return _getRidesByStatus('upcoming');
  }

  /// Returns bookings whose status is completed.
  Stream<List<RideHistoryModel>> getCompletedRides() {
    return _getRidesByStatus('completed');
  }

  /// Returns bookings whose status is cancelled.
  Stream<List<RideHistoryModel>> getCancelledRides() {
    return _getRidesByStatus('cancelled');
  }

  Stream<List<RideHistoryModel>> _getRidesByStatus(String status) {
    try {
      final String passengerId = _currentUserId;

      return _bookingsCollection
          .where('passengerId', isEqualTo: passengerId)
          .where('status', isEqualTo: status)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<RideHistoryModel> rides = snapshot.docs.map((
              QueryDocumentSnapshot<Map<String, dynamic>> document,
            ) {
              return RideHistoryModel.fromFirestore(document);
            }).toList();

            rides.sort((RideHistoryModel first, RideHistoryModel second) {
              return second.bookedAt.compareTo(first.bookedAt);
            });

            return rides;
          });
    } catch (error) {
      return Stream<List<RideHistoryModel>>.error(error);
    }
  }

  /// Creates a booking/history record.
  Future<String> addRideHistory({required RideHistoryModel rideHistory}) async {
    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _bookingsCollection.add(rideHistory.toMap());

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception(error.message ?? 'Unable to create ride history.');
    } catch (error) {
      throw Exception('Unable to create ride history: $error');
    }
  }

  /// Changes the status of a booking.
  Future<void> updateRideStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      final String normalizedStatus = status.trim().toLowerCase();

      const List<String> allowedStatuses = <String>[
        'upcoming',
        'completed',
        'cancelled',
      ];

      if (!allowedStatuses.contains(normalizedStatus)) {
        throw ArgumentError(
          'Status must be upcoming, completed, or cancelled.',
        );
      }

      await _bookingsCollection.doc(bookingId).update(<String, dynamic>{
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw Exception(error.message ?? 'Unable to update ride status.');
    } catch (error) {
      throw Exception('Unable to update ride status: $error');
    }
  }

  /// Marks a booking as completed.
  Future<void> markRideAsCompleted({required String bookingId}) async {
    await updateRideStatus(bookingId: bookingId, status: 'completed');
  }

  /// Cancels a booking.
  Future<void> cancelRide({required String bookingId}) async {
    await updateRideStatus(bookingId: bookingId, status: 'cancelled');
  }

  /// Deletes a booking history document permanently.
  Future<void> deleteRideHistory({required String bookingId}) async {
    try {
      await _bookingsCollection.doc(bookingId).delete();
    } on FirebaseException catch (error) {
      throw Exception(error.message ?? 'Unable to delete ride history.');
    } catch (error) {
      throw Exception('Unable to delete ride history: $error');
    }
  }
}
