import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../../../services/notification_service.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  String get currentUserId {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('User is not logged in.');
    return user.uid;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfileStream() {
    return _firestore.collection('users').doc(currentUserId).snapshots();
  }

  Future<Map<String, dynamic>> getProfile() async {
    final String uid = currentUserId;
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    if (snapshot.exists && snapshot.data() != null) {
      return snapshot.data()!;
    }
    return {};
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicle,
    String? vehicleNumber,
    int? seats,
    String? drivingLicence,
    String? upiId,
    String? upiMobileNumber,
    String? upiQrImageUrl,
    String? emergencyContact,
    String? bio,
    String? gender,
    int? avatarIndex,
    String? licenceImageUrl,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('User is not logged in.');

    await _firestore.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'phone': phone.trim(),
      if (vehicleModel != null) 'vehicleModel': vehicleModel.trim(),
      if (vehicleColor != null) 'vehicleColor': vehicleColor.trim(),
      if (vehicle != null) 'vehicle': vehicle.trim(),
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber.trim(),
      'seats': ?seats,
      if (drivingLicence != null) 'drivingLicence': drivingLicence.trim(),
      if (upiId != null) 'upiId': upiId.trim(),
      if (upiMobileNumber != null) 'upiMobileNumber': upiMobileNumber.trim(),
      'upiQrImageUrl': ?upiQrImageUrl,
      if (emergencyContact != null) 'emergencyContact': emergencyContact.trim(),
      if (bio != null) 'bio': bio.trim(),
      if (gender != null) 'gender': gender.trim(),
      'avatarIndex': ?avatarIndex,
      if (avatarIndex != null) 'photoUrl': FieldValue.delete(),
      'licenceImageUrl': ?licenceImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.updateDisplayName(name.trim());
    await user.reload();
  }

  Future<String> uploadProfilePicture(File imageFile) async {
    final String uid = currentUserId;
    final Reference ref = _storage
        .ref()
        .child('user_profiles')
        .child('$uid.jpg');

    final UploadTask uploadTask = ref.putFile(imageFile);
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    await _firestore.collection('users').doc(uid).set({
      'photoUrl': downloadUrl,
      'avatarIndex': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _auth.currentUser?.updatePhotoURL(downloadUrl);
    return downloadUrl;
  }

  Future<void> updateAvatar(int avatarIndex) async {
    if (avatarIndex < 0 || avatarIndex > 15) {
      throw ArgumentError.value(avatarIndex, 'avatarIndex', 'Must be 0-15');
    }

    final String uid = currentUserId;
    await _firestore.collection('users').doc(uid).set({
      'avatarIndex': avatarIndex,
      'photoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> uploadDrivingLicence(File imageFile) async {
    final String uid = currentUserId;
    final Reference ref = _storage
        .ref()
        .child('user_licences')
        .child('$uid.jpg');

    final UploadTask uploadTask = ref.putFile(imageFile);
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    await _firestore.collection('users').doc(uid).set({
      'licenceImageUrl': downloadUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return downloadUrl;
  }

  Future<void> syncAuthPhoneNumber() async {
    final user = _auth.currentUser;
    if (user == null || user.phoneNumber == null || user.phoneNumber!.isEmpty) {
      return;
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    // Only update if phone is missing in Firestore
    if (data == null ||
        data['phone'] == null ||
        data['phone'].toString().isEmpty) {
      // Strip country code if needed or keep as is. Usually Firebase keeps +91...
      // For this app, let's keep the full number.
      await _firestore.collection('users').doc(user.uid).set({
        'phone': user.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> signOut() async {
    await NotificationService.instance.removeCurrentTokenOnLogout();
    await _auth.signOut();
  }

  /// Permanently deletes the current user's profile data and Auth account.
  ///
  /// Ride/booking transaction records that reference this user are
  /// intentionally kept (for the other party's ride history and dispute
  /// resolution) rather than deleted here — see the privacy policy for the
  /// retention disclosure. Only personally-identifying data owned solely by
  /// this user (profile doc, profile photo, licence image, Auth account) is
  /// removed.
  ///
  /// Throws [FirebaseAuthException] with code `requires-recent-login` if the
  /// user's session is too old to allow account deletion; the caller should
  /// prompt the user to sign in again and retry.
  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('User is not logged in.');
    final String uid = user.uid;

    await NotificationService.instance.removeCurrentTokenOnLogout();

    for (final path in ['user_profiles/$uid.jpg', 'user_licences/$uid.jpg']) {
      try {
        await _storage.ref().child(path).delete();
      } on FirebaseException {
        // Fine if the file never existed; nothing else to do here.
      }
    }

    await _firestore.collection('users').doc(uid).delete();

    // Throws requires-recent-login if the session is stale; caller handles it.
    await user.delete();
  }
}
