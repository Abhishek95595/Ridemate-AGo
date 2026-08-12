import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingModel {
  final String id;
  final String rideId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String passengerEmail;
  final String pickup;
  final String destination;
  final String date;
  final String time;
  final String status;
  final String otp;
  final int seatsBooked;
  final num price;
  final Map<String, dynamic> driverDetails;
  final DateTime? createdAt;

  num get totalPrice {
    final int seats = seatsBooked > 0 ? seatsBooked : 1;
    return price * seats;
  }

  // Payment fields
  final String paymentStatus;
  final String? paymentMethod;
  final double? paymentAmount;
  final DateTime? paymentSubmittedAt;
  final DateTime? paymentVerifiedAt;
  final String? paymentSubmittedBy;
  final String? paymentVerifiedBy;
  final DateTime? completedAt;

  const BookingModel({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerEmail,
    required this.pickup,
    required this.destination,
    required this.date,
    required this.time,
    required this.status,
    required this.otp,
    required this.seatsBooked,
    required this.price,
    required this.driverDetails,
    required this.createdAt,
    required this.paymentStatus,
    this.paymentMethod,
    this.paymentAmount,
    this.paymentSubmittedAt,
    this.paymentVerifiedAt,
    this.paymentSubmittedBy,
    this.paymentVerifiedBy,
    this.completedAt,
  });

  factory BookingModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'];
    final submittedAt = data['paymentSubmittedAt'];
    final verifiedAt = data['paymentVerifiedAt'];
    final completedAt = data['completedAt'];

    return BookingModel(
      id: document.id,
      rideId: (data['rideId'] ?? '').toString(),
      driverId: (data['driverId'] ?? '').toString(),
      passengerId: (data['passengerId'] ?? '').toString(),
      passengerName: (data['passengerName'] ?? 'Passenger').toString(),
      passengerEmail: (data['passengerEmail'] ?? '').toString(),
      pickup: (data['pickup'] ?? '').toString(),
      destination: (data['destination'] ?? '').toString(),
      date: (data['date'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      otp: (data['otp'] ?? '').toString(),
      seatsBooked: int.tryParse((data['seatsBooked'] ?? 1).toString()) ?? 1,
      price: num.tryParse((data['price'] ?? 0).toString()) ?? 0,
      driverDetails: Map<String, dynamic>.from(
        data['driverDetails'] ?? const {},
      ),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      paymentStatus: (data['paymentStatus'] ?? 'pending').toString(),
      paymentMethod: data['paymentMethod'],
      paymentAmount: double.tryParse(data['paymentAmount']?.toString() ?? ''),
      paymentSubmittedAt: submittedAt is Timestamp
          ? submittedAt.toDate()
          : null,
      paymentVerifiedAt: verifiedAt is Timestamp ? verifiedAt.toDate() : null,
      paymentSubmittedBy: data['paymentSubmittedBy'],
      paymentVerifiedBy: data['paymentVerifiedBy'],
      completedAt: completedAt is Timestamp ? completedAt.toDate() : null,
    );
  }

  DateTime get departureTime {
    try {
      // Logic to parse "2024-08-01" and "10:43" into a single DateTime
      final dateStr = date; // e.g., "2024-08-01"
      final timeStr = time; // e.g., "10:43 AM" or "22:43"

      // Try flexible parsing
      DateFormat format;
      if (timeStr.contains(RegExp(r'AM|PM', caseSensitive: false))) {
        format = DateFormat("yyyy-MM-dd hh:mm a");
      } else {
        format = DateFormat("yyyy-MM-dd HH:mm");
      }

      return format.parse("$dateStr $timeStr");
    } catch (e) {
      // Fallback to today if parsing fails
      return DateTime.now().add(const Duration(hours: 1));
    }
  }

  String get normalizedVehicleType {
    final rawType =
        (driverDetails['vehicleType'] ?? driverDetails['vehicle'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (rawType.contains('bike') ||
        rawType.contains('motorcycle') ||
        rawType.contains('scooter') ||
        rawType.contains('scooty') ||
        rawType.contains('scoty') ||
        rawType.contains('2 wheeler') ||
        rawType.contains('two wheeler') ||
        rawType.contains('twowheeler') ||
        rawType == '2w' ||
        rawType == '2-wheeler') {
      return 'bike';
    }
    return 'car';
  }
}
