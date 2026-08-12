import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  final String id;
  final String driverId;
  final String driverName;
  final String driverPhotoUrl;
  final int? driverAvatarIndex;
  final double driverRating;
  final bool driverVerified;
  final String vehicleNumber;
  final String pickup;
  final String destination;
  final String date;
  final String time;
  final DateTime? departureTimestamp;
  final String vehicle;
  final String? vehicleType;
  final String? vehicleId;
  final int seats;

  String get normalizedVehicleType {
    final vt = (vehicleType ?? '').trim().toLowerCase();
    if (vt == 'bike') return 'bike';
    if (vt == 'car') return 'car';
    final v = vehicle.trim().toLowerCase();
    if (v.contains('bike') ||
        v.contains('motorcycle') ||
        v.contains('scooter') ||
        v.contains('scooty') ||
        v.contains('scoty') ||
        v.contains('2 wheeler') ||
        v.contains('two wheeler') ||
        v.contains('twowheeler') ||
        v == '2w' ||
        v == '2-wheeler') {
      return 'bike';
    }
    return 'car';
  }

  final int availableSeats;
  final int price;
  final String description;
  final bool ac;
  final bool smoking;
  final String status;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupGeoHash;
  final GeoPoint? pickupGeoPoint;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime? createdAt;
  final int driverCompletedRides;
  final int driverTotalReviews;

  const RideModel({
    this.id = '',
    required this.driverId,
    this.driverName = '',
    this.driverPhotoUrl = '',
    this.driverAvatarIndex,
    this.driverRating = 4.8,
    this.driverVerified = false,
    this.vehicleNumber = '',
    required this.pickup,
    required this.destination,
    required this.date,
    required this.time,
    this.departureTimestamp,
    required this.vehicle,
    this.vehicleType,
    this.vehicleId,
    required this.seats,
    this.availableSeats = 0,
    required this.price,
    this.description = '',
    this.ac = false,
    this.smoking = false,
    this.status = 'active',
    this.pickupLat,
    this.pickupLng,
    this.pickupGeoHash,
    this.pickupGeoPoint,
    this.destinationLat,
    this.destinationLng,
    this.createdAt,
    this.driverCompletedRides = 0,
    this.driverTotalReviews = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhotoUrl': driverPhotoUrl,
      'driverAvatarIndex': driverAvatarIndex,
      'driverRating': driverRating,
      'driverVerified': driverVerified,
      'vehicleNumber': vehicleNumber,
      'pickup': pickup,
      'destination': destination,
      'date': date,
      'time': time,
      'departureTimestamp': departureTimestamp == null
          ? null
          : Timestamp.fromDate(departureTimestamp!),
      'vehicle': vehicle,
      'vehicleType': normalizedVehicleType,
      'vehicleId': vehicleId,
      'seats': seats,
      'availableSeats': availableSeats,
      'price': price,
      'description': description,
      'ac': ac,
      'smoking': smoking,
      'status': status,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupGeoHash': pickupGeoHash,
      'pickupGeoPoint': pickupGeoPoint,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'driverCompletedRides': driverCompletedRides,
      'driverTotalReviews': driverTotalReviews,
    };
  }

  factory RideModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RideModel(
      id: documentId,
      driverId: map['driverId']?.toString() ?? '',
      driverName: map['driverName']?.toString() ?? '',
      driverPhotoUrl: map['driverPhotoUrl']?.toString() ?? '',
      driverAvatarIndex: _toInt(map['driverAvatarIndex']),
      driverRating: _toDouble(map['driverRating']) ?? 4.8,
      driverVerified: map['driverVerified'] == true,
      vehicleNumber: map['vehicleNumber']?.toString() ?? '',
      pickup: map['pickup']?.toString() ?? '',
      destination: map['destination']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      departureTimestamp: map['departureTimestamp'] is Timestamp
          ? (map['departureTimestamp'] as Timestamp).toDate()
          : null,
      vehicle: map['vehicle']?.toString() ?? '',
      vehicleType: map['vehicleType']?.toString(),
      vehicleId: map['vehicleId']?.toString(),
      seats: _toInt(map['seats']),
      availableSeats: _toInt(map['availableSeats'] ?? map['seats']),
      price: _toInt(map['price']),
      description: map['description']?.toString() ?? '',
      ac: map['ac'] == true || map['hasAc'] == true,
      smoking: map['smoking'] == true || map['smokingAllowed'] == true,
      status: map['status']?.toString() ?? 'active',
      pickupLat:
          _toDouble(map['pickupLat']) ??
          ((map['pickupPosition'] as Map<String, dynamic>?)?['geopoint']
                  as GeoPoint?)
              ?.latitude,
      pickupLng:
          _toDouble(map['pickupLng']) ??
          ((map['pickupPosition'] as Map<String, dynamic>?)?['geopoint']
                  as GeoPoint?)
              ?.longitude,
      pickupGeoHash:
          map['pickupGeoHash']?.toString() ??
          (map['pickupPosition'] as Map<String, dynamic>?)?['geohash']
              ?.toString(),
      pickupGeoPoint: (map['pickupGeoPoint'] is GeoPoint)
          ? map['pickupGeoPoint'] as GeoPoint
          : (map['pickupPosition'] as Map<String, dynamic>?)?['geopoint']
                as GeoPoint?,
      destinationLat: _toDouble(map['destinationLat']),
      destinationLng: _toDouble(map['destinationLng']),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      driverCompletedRides: _toInt(map['driverCompletedRides']),
      driverTotalReviews: _toInt(map['driverTotalReviews']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  RideModel copyWith({
    String? id,
    String? driverId,
    String? pickup,
    String? destination,
    String? date,
    String? time,
    String? vehicle,
    int? seats,
    int? availableSeats,
    int? price,
    String? description,
    bool? ac,
    bool? smoking,
    String? status,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    DateTime? createdAt,
  }) {
    return RideModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      date: date ?? this.date,
      time: time ?? this.time,
      vehicle: vehicle ?? this.vehicle,
      seats: seats ?? this.seats,
      availableSeats: availableSeats ?? this.availableSeats,
      price: price ?? this.price,
      description: description ?? this.description,
      ac: ac ?? this.ac,
      smoking: smoking ?? this.smoking,
      status: status ?? this.status,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
