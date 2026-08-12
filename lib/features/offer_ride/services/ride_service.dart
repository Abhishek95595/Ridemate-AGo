import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:intl/intl.dart';

import '../models/ride_model.dart';

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _ridesCollection {
    return _firestore.collection('rides');
  }

  Future<void> publishRide(RideModel ride) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('Please login before publishing a ride.');
    }

    final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final Map<String, dynamic> profileData =
        profileSnapshot.data() ?? <String, dynamic>{};

    DateTime? departureTimestamp;
    try {
      final DateFormat format = DateFormat("d/M/yyyy h:mm a");
      departureTimestamp = format.parse("${ride.date} ${ride.time}");
    } catch (e) {
      debugPrint("Could not parse the ride departure time.");
    }

    final GeoFirePoint pickupLocation = GeoFirePoint(
      GeoPoint(ride.pickupLat!, ride.pickupLng!),
    );

    final Map<String, dynamic> rideData = ride.toMap();
    rideData['driverId'] = currentUser.uid;
    rideData['driverName'] =
        profileData['name'] ?? currentUser.displayName ?? 'AGo Driver';
    rideData['driverPhotoUrl'] =
        profileData['photoUrl'] ?? currentUser.photoURL ?? '';
    rideData['driverAvatarIndex'] =
        profileData['driverAvatarIndex'] ?? profileData['avatarIndex'];
    rideData['driverRating'] =
        profileData['averageRating'] ?? profileData['rating'] ?? 4.8;
    rideData['driverCompletedRides'] = profileData['completedRides'] ?? 0;
    rideData['driverTotalReviews'] = profileData['totalRatings'] ?? 0;
    rideData['driverVerified'] = profileData['isVerified'] ?? false;
    rideData['vehicleNumber'] = profileData['vehicleNumber'] ?? '';
    rideData['departureTimestamp'] = departureTimestamp != null
        ? Timestamp.fromDate(departureTimestamp)
        : null;

    // Save location using geoflutterfire_plus expected format
    rideData['pickupPosition'] = pickupLocation.data;

    rideData['status'] = 'active';
    rideData['createdAt'] = FieldValue.serverTimestamp();
    rideData['updatedAt'] = FieldValue.serverTimestamp();

    await _ridesCollection.add(rideData);
  }

  Stream<List<RideModel>> getMyRides() {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Stream<List<RideModel>>.value([]);
    }

    return _ridesCollection
        .where('driverId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          final List<RideModel> rides = snapshot.docs.map((document) {
            return RideModel.fromMap(document.data(), document.id);
          }).toList();

          rides.sort((firstRide, secondRide) {
            final DateTime firstDate = firstRide.createdAt ?? DateTime(2000);
            final DateTime secondDate = secondRide.createdAt ?? DateTime(2000);

            return secondDate.compareTo(firstDate);
          });

          return rides;
        });
  }

  Future<void> updateRide({
    required String rideId,
    required RideModel ride,
  }) async {
    if (rideId.trim().isEmpty) {
      throw Exception("Ride ID is missing.");
    }

    final docRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) throw Exception("Ride not found.");

      final data = snap.data()!;
      final int oldTotal = int.tryParse(data['seats']?.toString() ?? '0') ?? 0;
      final int oldAvailable =
          int.tryParse(
            data['availableSeats']?.toString() ??
                data['seats']?.toString() ??
                '0',
          ) ??
          0;

      final int bookedCount = oldTotal - oldAvailable;
      final int newAvailable = ride.seats - bookedCount;

      transaction.update(docRef, {
        'pickup': ride.pickup,
        'destination': ride.destination,
        'date': ride.date,
        'time': ride.time,
        'vehicle': ride.vehicle,
        'seats': ride.seats,
        'availableSeats': newAvailable,
        'description': ride.description,
        'status': ride.status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelRide(String rideId) async {
    if (rideId.trim().isEmpty) {
      throw Exception('Ride ID is missing.');
    }

    await _ridesCollection.doc(rideId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRide(String rideId) async {
    if (rideId.trim().isEmpty) {
      throw Exception('Ride ID is missing.');
    }

    await _ridesCollection.doc(rideId).delete();
  }
}
