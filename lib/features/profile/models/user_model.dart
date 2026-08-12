class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final int? avatarIndex;
  final String role;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicle; // Type
  final String? vehicleNumber;
  final int? seats;
  final String? drivingLicence;
  final String? upiId;
  final String? upiMobileNumber;
  final String? upiQrImageUrl;
  final String? emergencyContact;
  final String? bio;
  final String? gender;
  final bool profileCompleted;
  final double averageRating;
  final int totalRatings;
  final int completedRides;
  final String? licenceImageUrl;
  final bool isVerified;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    this.avatarIndex,
    required this.role,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicle,
    this.vehicleNumber,
    this.seats,
    this.drivingLicence,
    this.upiId,
    this.upiMobileNumber,
    this.upiQrImageUrl,
    this.emergencyContact,
    this.bio,
    this.gender,
    required this.profileCompleted,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.completedRides = 0,
    this.licenceImageUrl,
    this.isVerified = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      photoUrl: data['photoUrl'],
      avatarIndex: data['avatarIndex'],
      role: data['role'] ?? 'user',
      vehicleModel: data['vehicleModel'],
      vehicleColor: data['vehicleColor'],
      vehicle: data['vehicle'],
      vehicleNumber: data['vehicleNumber'],
      seats: data['seats'],
      drivingLicence: data['drivingLicence'],
      upiId: data['upiId'],
      upiMobileNumber: data['upiMobileNumber'],
      upiQrImageUrl: data['upiQrImageUrl'],
      emergencyContact: data['emergencyContact'],
      bio: data['bio'],
      gender: data['gender'],
      profileCompleted: data['profileCompleted'] ?? false,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      completedRides: data['completedRides'] ?? 0,
      licenceImageUrl: data['licenceImageUrl'],
      isVerified: data['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'avatarIndex': avatarIndex,
      'role': role,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehicle': vehicle,
      'vehicleNumber': vehicleNumber,
      'seats': seats,
      'drivingLicence': drivingLicence,
      'upiId': upiId,
      'upiMobileNumber': upiMobileNumber,
      'upiQrImageUrl': upiQrImageUrl,
      'emergencyContact': emergencyContact,
      'bio': bio,
      'gender': gender,
      'profileCompleted': profileCompleted,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'completedRides': completedRides,
      'licenceImageUrl': licenceImageUrl,
      'isVerified': isVerified,
    };
  }

  bool get hasBasicProfile =>
      name.isNotEmpty &&
      phone.isNotEmpty &&
      (photoUrl != null || avatarIndex != null);

  bool get isDriverEligible =>
      hasBasicProfile &&
      drivingLicence != null &&
      drivingLicence!.isNotEmpty &&
      upiId != null &&
      upiId!.isNotEmpty;
}
