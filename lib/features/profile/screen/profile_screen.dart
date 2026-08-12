import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/login/login_screen.dart';
import '../../../core/constant/app_links.dart';
import '../../../core/widgets/app_avatar.dart';
import 'edit_profile_screen.dart';
import 'profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _teal = Color(0xFF16BDB5);
  static const Color _navy = Color(0xFF08234C);
  static const Color _mint = Color(0xFFE8FAF7);

  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _profileService.syncAuthPhoneNumber();
  }

  Future<void> logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: GoogleFonts.poppins(
              color: _navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.poppins(color: _navy),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'CANCEL',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'LOGOUT',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _profileService.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> deleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Account',
            style: GoogleFonts.poppins(
              color: _navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This permanently deletes your profile, photo and login. '
            'This cannot be undone. Are you sure you want to continue?',
            style: GoogleFonts.poppins(color: _navy),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'CANCEL',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'DELETE',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _profileService.deleteAccount();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'requires-recent-login') {
        await _profileService.signOut();
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'For your security, please log in again and retry deleting your account.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return const Scaffold(body: Center(child: Text('Please login.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4FCFA),
      appBar: AppBar(
        backgroundColor: _mint,
        foregroundColor: _navy,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(fontSize: 23, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileService.getProfileStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }

          final Map<String, dynamic> data =
              snapshot.data?.data() ?? <String, dynamic>{};
          final String name = (data['name'] ?? authUser.displayName ?? 'User')
              .toString();
          final String email = (data['email'] ?? authUser.email ?? '')
              .toString();
          final String phone = (data['phone'] ?? 'Not added').toString();
          final String gender = (data['gender'] ?? 'Not added').toString();
          final String bio = (data['bio'] ?? 'Not added').toString();
          final String photoUrl = (data['photoUrl'] ?? authUser.photoURL ?? '')
              .toString();
          final dynamic storedAvatar = data['avatarIndex'];
          final int? avatarIndex = storedAvatar is int
              ? storedAvatar
              : int.tryParse(storedAvatar?.toString() ?? '');

          final String vehicleNumber = (data['vehicleNumber'] ?? '').toString();
          final String vehicleModel = (data['vehicleModel'] ?? '').toString();
          final String vehicleType = (data['vehicle'] ?? '').toString();
          final String vehicle = vehicleNumber.isNotEmpty
              ? vehicleNumber
              : vehicleModel.isNotEmpty
              ? vehicleModel
              : vehicleType.isNotEmpty
              ? vehicleType
              : 'Not added';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              children: [
                _buildProfileHero(
                  photoUrl: photoUrl,
                  avatarIndex: avatarIndex,
                  data: data,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: _navy,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: _navy.withValues(alpha: 0.82),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 23),
                      SizedBox(
                        width: double.infinity,
                        height: 57,
                        child: ElevatedButton.icon(
                          onPressed: () => _openEditProfile(data),
                          icon: const Icon(Icons.edit_outlined, size: 23),
                          label: Text(
                            'EDIT PROFILE',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      _buildInfoCard(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: phone,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.people_outline_rounded,
                        label: 'Gender',
                        value: gender,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.directions_car_outlined,
                        label: 'Vehicle',
                        value: vehicle,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.info_outline_rounded,
                        label: 'About You',
                        value: bio,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 53,
                        child: OutlinedButton.icon(
                          onPressed: logout,
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: Text(
                            'LOGOUT',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(privacyPolicyUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Text(
                              'Privacy Policy',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(termsOfServiceUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Text(
                              'Terms & Conditions',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: deleteAccount,
                        child: Text(
                          'Delete Account',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHero({
    required String photoUrl,
    required int? avatarIndex,
    required Map<String, dynamic> data,
  }) {
    return SizedBox(
      height: 315,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 245,
            child: Image.asset(
              'assets/images/profile_hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: () => _openEditProfile(data),
              child: Container(
                width: 144,
                height: 144,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _mint,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD5F1ED), width: 2),
                ),
                child: AppAvatar(
                  avatarIndex: avatarIndex,
                  photoUrl: photoUrl,
                  size: 132,
                  borderColor: Colors.transparent,
                  borderWidth: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5F1EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 61,
            height: 61,
            decoration: const BoxDecoration(
              color: Color(0xFFE4F8F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _navy, size: 31),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEditProfile(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(profileData: data)),
    );
  }
}
