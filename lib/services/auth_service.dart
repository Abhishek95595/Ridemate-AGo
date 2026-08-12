import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await NotificationService.instance.updateToken();
    return cred;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      await user.updateDisplayName(name);

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': name.trim(),
        'email': email.trim(),
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'profileImage': "",
        'phoneNumber': "",
        'role': 'user',
        'authProvider': 'email',
        'profileCompleted': false,
      });

      await NotificationService.instance.updateToken();
      await user.sendEmailVerification();
    }

    return userCredential;
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() async {
    await NotificationService.instance.removeCurrentTokenOnLogout();
    await _auth.signOut();
  }

  Future<void> updateFirestoreVerificationStatus() async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      await _firestore.collection('users').doc(user.uid).update({
        'emailVerified': true,
      });
    }
  }
}
