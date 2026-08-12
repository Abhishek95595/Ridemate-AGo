import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/bookings/models/booking_model.dart';

class SosService {
  static final SosService instance = SosService._internal();
  factory SosService() => instance;
  SosService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _locationUpdateTimer;

  Future<Map<String, String>?> fetchEmergencyContact() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final contactName =
        data['emergencyContactName']?.toString() ?? 'Emergency Contact';
    final contactPhone =
        (data['emergencyContact'] ?? data['emergencyContactPhone'])
            ?.toString() ??
        '';

    if (contactPhone.isEmpty) return null;

    return {'name': contactName, 'phone': contactPhone};
  }

  Future<void> triggerSOS(BookingModel booking, Position currentPos) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final alertRef = _firestore.collection('sos_alerts').doc();

    await alertRef.set({
      'alertId': alertRef.id,
      'riderId': user.uid,
      'riderName': user.displayName ?? 'Rider',
      'driverId': booking.driverId,
      'rideId': booking.rideId,
      'bookingId': booking.id,
      'location': GeoPoint(currentPos.latitude, currentPos.longitude),
      'status': 'active',
      'timestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await alertRef.update({
          'location': GeoPoint(pos.latitude, pos.longitude),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("SOS background update failed: $e");
      }
    });
  }

  Future<void> stopSOS() async {
    _locationUpdateTimer?.cancel();
  }

  Future<void> sendSOSMessage(
    String contactPhone,
    BookingModel booking,
    Position pos,
  ) async {
    final mapsLink =
        "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}";
    final driver = booking.driverDetails;

    final String cleanPhone = contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    final message =
        "SOS EMERGENCY! I'm on a AGo trip and need help. "
        "Loc: $mapsLink . "
        "Driver: ${driver['name'] ?? 'N/A'}, ${driver['vehicleNumber'] ?? ''}";

    final Uri smsUri = Uri.parse(
      'sms:$cleanPhone?body=${Uri.encodeComponent(message)}',
    );

    try {
      // Manually redirect to SMS app as requested
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      }
      debugPrint("Redirected to SMS app for manual SOS dispatch.");
    } catch (e) {
      debugPrint("SOS SMS launch failed: $e");
    }
  }

  Future<void> callEmergencyContact(String phone) async {
    final Uri callUri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Call launch failed: $e");
    }
  }
}
