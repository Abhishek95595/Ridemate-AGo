import 'package:cloud_firestore/cloud_firestore.dart';

class RideHistoryModel {
  final String id;
  final String rideId;
  final String driverId;
  final String passengerId;
  final String pickup;
  final String destination;
  final String date;
  final String time;
  final int seats;
  final double price;
  final String status;
  final DateTime bookedAt;

  const RideHistoryModel({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.pickup,
    required this.destination,
    required this.date,
    required this.time,
    required this.seats,
    required this.price,
    required this.status,
    required this.bookedAt,
  });

  factory RideHistoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? {};

    return RideHistoryModel(
      id: document.id,
      rideId: data['rideId']?.toString() ?? '',
      driverId: data['driverId']?.toString() ?? '',
      passengerId: data['passengerId']?.toString() ?? '',
      pickup: data['pickup']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      date: data['date']?.toString() ?? '',
      time: data['time']?.toString() ?? '',
      seats: _parseInt(data['seats']),
      price: _parseDouble(data['price']),
      status: data['status']?.toString() ?? 'upcoming',
      bookedAt: _parseDateTime(data['bookedAt']),
    );
  }

  factory RideHistoryModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return RideHistoryModel(
      id: id,
      rideId: data['rideId']?.toString() ?? '',
      driverId: data['driverId']?.toString() ?? '',
      passengerId: data['passengerId']?.toString() ?? '',
      pickup: data['pickup']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      date: data['date']?.toString() ?? '',
      time: data['time']?.toString() ?? '',
      seats: _parseInt(data['seats']),
      price: _parseDouble(data['price']),
      status: data['status']?.toString() ?? 'upcoming',
      bookedAt: _parseDateTime(data['bookedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rideId': rideId,
      'driverId': driverId,
      'passengerId': passengerId,
      'pickup': pickup,
      'destination': destination,
      'date': date,
      'time': time,
      'seats': seats,
      'price': price,
      'status': status,
      'bookedAt': Timestamp.fromDate(bookedAt),
    };
  }

  RideHistoryModel copyWith({
    String? id,
    String? rideId,
    String? driverId,
    String? passengerId,
    String? pickup,
    String? destination,
    String? date,
    String? time,
    int? seats,
    double? price,
    String? status,
    DateTime? bookedAt,
  }) {
    return RideHistoryModel(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      driverId: driverId ?? this.driverId,
      passengerId: passengerId ?? this.passengerId,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      date: date ?? this.date,
      time: time ?? this.time,
      seats: seats ?? this.seats,
      price: price ?? this.price,
      status: status ?? this.status,
      bookedAt: bookedAt ?? this.bookedAt,
    );
  }

  bool get isUpcoming => status.toLowerCase() == 'upcoming';

  bool get isCompleted => status.toLowerCase() == 'completed';

  bool get isCancelled => status.toLowerCase() == 'cancelled';

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}
