import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LiveLocationService {
  LiveLocationService._();

  static final LiveLocationService instance = LiveLocationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionSubscription;

  String? _activeRideId;

  bool get isTracking => _positionSubscription != null && _activeRideId != null;

  Future<bool> requestPermissions() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint('Location service is disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      debugPrint('Location permission denied.');
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied.');
      return false;
    }

    return true;
  }

  Future<void> startTrackingRide({required String rideId}) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('Cannot start tracking: user is not logged in.');
    }

    final String cleanRideId = rideId.trim();

    if (cleanRideId.isEmpty) {
      throw Exception('Cannot start tracking: ride ID is empty.');
    }

    final bool hasPermission = await requestPermissions();

    if (!hasPermission) {
      throw Exception('Location permission or GPS is unavailable.');
    }

    /*
     * Important:
     * Make sure this phone belongs to the driver.
     * This prevents the passenger's location from being
     * written as the driver's live location.
     */
    final DocumentSnapshot<Map<String, dynamic>> rideSnapshot = await _firestore
        .collection('rides')
        .doc(cleanRideId)
        .get();

    if (!rideSnapshot.exists) {
      throw Exception('Ride does not exist.');
    }

    final Map<String, dynamic>? rideData = rideSnapshot.data();

    if (rideData == null) {
      throw Exception('Ride data is unavailable.');
    }

    final String storedDriverId =
        (rideData['driverId'] ??
                rideData['userId'] ??
                rideData['offeredBy'] ??
                '')
            .toString();

    if (storedDriverId.isNotEmpty && storedDriverId != user.uid) {
      throw Exception('Only the driver can share live location.');
    }

    await stopTracking();

    _activeRideId = cleanRideId;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    /*
     * First send one fresh location.
     */
    try {
      final Position initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (_isUsablePosition(initialPosition)) {
        await _updateLocationInFirestore(
          rideId: cleanRideId,
          driverId: user.uid,
          position: initialPosition,
        );
      } else {
        debugPrint('Initial position rejected because it is inaccurate.');
      }
    } catch (error, stackTrace) {
      debugPrint('Could not get initial driver location: $error');

      debugPrintStack(stackTrace: stackTrace);
    }

    /*
     * Continue sending live GPS updates.
     */
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            if (_activeRideId != cleanRideId) {
              return;
            }

            if (!_isUsablePosition(position)) {
              debugPrint(
                'GPS reading ignored: '
                'lat=${position.latitude}, '
                'lng=${position.longitude}, '
                'accuracy=${position.accuracy}',
              );
              return;
            }

            try {
              await _updateLocationInFirestore(
                rideId: cleanRideId,
                driverId: user.uid,
                position: position,
              );
            } catch (error, stackTrace) {
              debugPrint('Live-location update failed: $error');

              debugPrintStack(stackTrace: stackTrace);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Position stream error: $error');

            debugPrintStack(stackTrace: stackTrace);
          },
          cancelOnError: false,
        );
  }

  bool _isUsablePosition(Position position) {
    final double latitude = position.latitude;
    final double longitude = position.longitude;

    final bool validCoordinates =
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;

    if (!validCoordinates) {
      return false;
    }

    /*
     * Ignore very inaccurate readings.
     *
     * Accuracy is reported in metres.
     * Increase 100 to 150 if indoor testing
     * rejects too many readings.
     */
    if (!position.accuracy.isFinite || position.accuracy > 100) {
      return false;
    }

    return true;
  }

  Future<void> _updateLocationInFirestore({
    required String rideId,
    required String driverId,
    required Position position,
  }) async {
    final Map<String, dynamic> locationData = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'heading': position.heading,
      'bearing': position.heading,
      'speed': position.speed,
      'altitude': position.altitude,
      'driverId': driverId,
      'recordedAt': Timestamp.fromDate(position.timestamp),
      'updatedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('rides').doc(rideId).update(<String, dynamic>{
      'liveLocation': locationData,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      'Driver location uploaded: '
      '${position.latitude}, '
      '${position.longitude}, '
      'accuracy=${position.accuracy}m',
    );
  }

  Stream<Map<String, dynamic>?> watchLiveLocation(String rideId) {
    return _firestore.collection('rides').doc(rideId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (data == null) {
        return null;
      }

      final dynamic rawLocation = data['liveLocation'];

      if (rawLocation is! Map) {
        return null;
      }

      final Map<String, dynamic> location = Map<String, dynamic>.from(
        rawLocation,
      );

      final dynamic latitudeValue = location['latitude'];

      final dynamic longitudeValue = location['longitude'];

      if (latitudeValue is! num || longitudeValue is! num) {
        return null;
      }

      final double latitude = latitudeValue.toDouble();

      final double longitude = longitudeValue.toDouble();

      final bool valid =
          latitude.isFinite &&
          longitude.isFinite &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;

      if (!valid) {
        return null;
      }

      /*
         * Ignore old location left from a previous ride session.
         */
      final dynamic timestampValue = location['timestamp'];

      if (timestampValue is Timestamp) {
        final DateTime updatedAt = timestampValue.toDate();

        final Duration age = DateTime.now().difference(updatedAt);

        if (age > const Duration(minutes: 5)) {
          debugPrint(
            'Ignoring stale driver location. '
            'Age: ${age.inMinutes} minutes.',
          );

          return null;
        }
      }

      return location;
    });
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;
    _activeRideId = null;
  }

  Future<void> clearLiveLocation({required String rideId}) async {
    await stopTracking();

    await _firestore.collection('rides').doc(rideId).update(<String, dynamic>{
      'liveLocation': FieldValue.delete(),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
