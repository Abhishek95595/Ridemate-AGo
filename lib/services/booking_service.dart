import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/bookings/models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not logged in.');
    }
    return user.uid;
  }

  Stream<List<BookingModel>> getDriverRequests() {
    return _firestore
        .collection('bookings')
        .where('driverId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map(BookingModel.fromDocument).toList();
          items.sort((a, b) {
            final first = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final second =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return second.compareTo(first);
          });
          return items;
        });
  }

  Stream<List<BookingModel>> getPassengerBookings() {
    return _firestore
        .collection('bookings')
        .where('passengerId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map(BookingModel.fromDocument).toList();
          items.sort((a, b) {
            final first = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final second =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return second.compareTo(first);
          });
          return items;
        });
  }

  Future<Map<String, dynamic>> _loadDriverDetails(String driverId) async {
    final userSnapshot = await _firestore
        .collection('users')
        .doc(driverId)
        .get();
    final userData = userSnapshot.data() ?? <String, dynamic>{};

    return {
      'name': userData['name'] ?? '',
      'phone': userData['phone'] ?? '',
      'photoUrl': userData['photoUrl'] ?? '',
      'avatarIndex': userData['avatarIndex'],
      'vehicle': userData['vehicle'] ?? '',
      'vehicleModel': userData['vehicleModel'] ?? userData['vehicle'] ?? '',
      'vehicleType': userData['vehicleType'] ?? userData['vehicle'] ?? '',
      'vehicleNumber': userData['vehicleNumber'] ?? '',
      'vehicleColor': userData['vehicleColor'] ?? '',
      'rating': userData['rating'] ?? 0,
    };
  }

  Future<void> acceptBooking(BookingModel booking) async {
    final details = await _loadDriverDetails(currentUserId);
    final String otp = (Random().nextInt(9000) + 1000).toString();

    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    final notificationRef = _firestore.collection('notifications').doc();

    final batch = _firestore.batch();

    // NOTE: Seats were already decremented in bookRide (FindRideScreen) to reserve them.
    // We just update the booking status here.

    batch.update(bookingRef, {
      'status': 'accepted',
      'driverDetails': details,
      'otp': otp,
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(notificationRef, {
      'notificationId': notificationRef.id,
      'receiverId': booking.passengerId,
      'senderId': currentUserId,
      'type': 'booking_accepted',
      'title': 'Ride Booked Successfully! ✅',
      'message':
          '${details['name'] ?? 'Your driver'} accepted your ride from ${booking.pickup} to ${booking.destination}.',
      'rideId': booking.rideId,
      'bookingId': booking.id,
      'driverName': details['name'] ?? '',
      'driverPhone': details['phone'] ?? '',
      'vehicle': details['vehicle'] ?? '',
      'vehicleNumber': details['vehicleNumber'] ?? '',
      'otp': otp,
      'date': booking.date,
      'time': booking.time,
      'pickup': booking.pickup,
      'destination': booking.destination,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> rejectBooking(BookingModel booking) async {
    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    final notificationRef = _firestore.collection('notifications').doc();
    final rideRef = _firestore.collection('rides').doc(booking.rideId);

    await _firestore.runTransaction((transaction) async {
      // 1. Get current ride state to ensure field exists
      final rideSnap = await transaction.get(rideRef);
      if (!rideSnap.exists) return; // Ride deleted? Skip seat rollback.

      final rideData = rideSnap.data()!;
      final int currentAvailable =
          int.tryParse(
            (rideData['availableSeats'] ?? rideData['seats'] ?? '0').toString(),
          ) ??
          0;

      // 2. Update booking status
      transaction.update(bookingRef, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Set notification
      transaction.set(notificationRef, {
        'notificationId': notificationRef.id,
        'receiverId': booking.passengerId,
        'senderId': currentUserId,
        'type': 'booking_rejected',
        'title': 'Ride Request Update',
        'message':
            'The driver could not accept your ride request from ${booking.pickup} to ${booking.destination}.',
        'rideId': booking.rideId,
        'bookingId': booking.id,
        'pickup': booking.pickup,
        'destination': booking.destination,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Restore seats atomically
      transaction.update(rideRef, {
        'availableSeats': currentAvailable + booking.seatsBooked,
      });
    });
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final bookingSnapshot = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!bookingSnapshot.exists) return;

    final data = bookingSnapshot.data()!;
    final passengerId = data['passengerId'];
    final pickup = data['pickup'];
    final destination = data['destination'];
    final driverDetails = data['driverDetails'] as Map<String, dynamic>? ?? {};

    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send Notification
    String title = "Ride Update";
    String message = "Your ride status has changed.";
    Map<String, dynamic> extraData = {};

    switch (status) {
      case 'started':
        title = "Ride Started! 🚗";
        message = "Your driver has started the ride from $pickup.";
        break;
      case 'arrived':
        title = "Driver Arrived! 📍";
        message = "Your driver is waiting at $pickup.";
        break;
      case 'completed':
        title = "Ride Completed! 🏁";
        message = "You have reached $destination. Hope you had a great ride!";
        extraData = {
          'driverName': driverDetails['name'] ?? 'Driver',
          'driverPhone': driverDetails['phone'] ?? '',
          'driverId': data['driverId'],
        };
        break;
    }

    await _firestore.collection('notifications').add({
      'receiverId': passengerId,
      'senderId': currentUserId,
      'type': 'ride_update',
      'status': status,
      'title': title,
      'message': message,
      'bookingId': bookingId,
      ...extraData,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelBooking(BookingModel booking) async {
    final batch = _firestore.batch();
    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    final notificationRef = _firestore.collection('notifications').doc();
    final rideRef = _firestore.collection('rides').doc(booking.rideId);

    batch.update(bookingRef, {
      'status': 'cancelled',
      'cancelledBy': currentUserId,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(notificationRef, {
      'notificationId': notificationRef.id,
      'receiverId': booking.driverId,
      'senderId': currentUserId,
      'type': 'booking_cancelled',
      'title': 'Ride Cancelled ❌',
      'message':
          '${booking.passengerName} has cancelled the ride from ${booking.pickup} to ${booking.destination}.',
      'bookingId': booking.id,
      'rideId': booking.rideId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Restore seats to the ride
    // We restore for BOTH pending and accepted, because seats are now
    // reserved immediately when the user books.
    batch.update(rideRef, {
      'availableSeats': FieldValue.increment(booking.seatsBooked),
    });

    await batch.commit();
  }

  Future<void> initiatePaymentFlow(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'payment_pending',
      'paymentStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitPayment({
    required String bookingId,
    required String passengerId,
    required double amount,
  }) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'paymentStatus': 'submitted_by_passenger',
      'paymentMethod': 'qr',
      'paymentAmount': amount,
      'paymentSubmittedBy': passengerId,
      'paymentSubmittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> verifyPayment({
    required String bookingId,
    required String driverId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      final driverRef = _firestore.collection('users').doc(driverId);

      // 1. Update booking status
      transaction.update(bookingRef, {
        'paymentStatus': 'verified_by_driver',
        'status': 'completed',
        'paymentVerifiedBy': driverId,
        'paymentVerifiedAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Increment driver's completed rides count
      transaction.update(driverRef, {
        'completedRides': FieldValue.increment(1),
      });

      // 3. Update any active rides by this driver with new stats
      final ridesQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in ridesQuery.docs) {
        transaction.update(doc.reference, {
          'driverCompletedRides': FieldValue.increment(1),
        });
      }
    });
  }

  Future<void> completeBooking(BookingModel booking) async {
    await initiatePaymentFlow(booking.id);
  }
}
