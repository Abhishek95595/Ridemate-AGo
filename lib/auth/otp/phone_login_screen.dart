import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/home/home_screen.dart';
import '../widgets/auth_ui.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _verificationId = '';
  int? _resendToken;
  bool isOtpSent = false;
  bool isLoading = false;

  void sendOtp() async {
    final String phone = phoneController.text.trim();
    if (phone.length != 10) {
      _showMessage('Enter a valid 10-digit number.', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone', // Defaulting to India as per API components
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (on Android)
          await _auth.signInWithCredential(credential);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => isLoading = false);
          _showMessage(e.message ?? 'Verification failed.', isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            isLoading = false;
            isOtpSent = true;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _showMessage('OTP sent to $phone', isError: false);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showMessage('Error: $e', isError: true);
      }
    }
  }

  void verifyOtp() async {
    final String smsCode = otpController.text.trim();
    if (smsCode.length != 6) {
      _showMessage('Enter the 6-digit code.', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);

      if (!mounted) return;
      setState(() => isLoading = false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showMessage(e.message ?? 'Invalid OTP.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showMessage('Verification error.', isError: true);
      }
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : AuthUi.tealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
          child: Column(
            children: [
              const AuthHeroIcon(),
              const SizedBox(height: 28),
              Text(
                isOtpSent ? 'Verify OTP' : 'Phone Login',
                textAlign: TextAlign.center,
                style: AuthUi.titleStyle(context, size: 35),
              ),
              const SizedBox(height: 8),
              Text(
                isOtpSent
                    ? 'Enter the 6-digit code sent to your phone'
                    : 'Enter your phone number to receive a secure code',
                textAlign: TextAlign.center,
                style: AuthUi.subtitleStyle(context),
              ),
              const SizedBox(height: 42),

              if (!isOtpSent)
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  decoration: AuthUi.inputDecoration(
                    context,
                    hint: 'Phone Number',
                    icon: Icons.phone_android_rounded,
                  ).copyWith(counterText: ''),
                )
              else
                TextFormField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  decoration: AuthUi.inputDecoration(
                    context,
                    hint: '6-digit OTP',
                    icon: Icons.lock_clock_outlined,
                  ).copyWith(counterText: ''),
                ),

              const SizedBox(height: 32),

              AuthPrimaryButton(
                label: isOtpSent ? 'VERIFY & LOGIN' : 'SEND OTP',
                loading: isLoading,
                onPressed: isLoading ? null : (isOtpSent ? verifyOtp : sendOtp),
              ),

              const SizedBox(height: 25),
              const AuthOrDivider(),
              const SizedBox(height: 15),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Back to Login',
                  style: GoogleFonts.poppins(
                    color: AuthUi.tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Your number is used only for account verification and secure AGo communication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
