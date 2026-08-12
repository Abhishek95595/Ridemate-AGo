import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../login/login_screen.dart';
import '../widgets/auth_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String email = emailController.text.trim();

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      setState(() => isLoading = false);

      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      String message = 'An error occurred. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email address.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send reset link.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: const Icon(
            Icons.mark_email_read_rounded,
            color: AuthUi.teal,
            size: 42,
          ),
          title: Text(
            'Reset Link Sent',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AuthUi.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Password reset link has been sent to\n${emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF65707D), fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _goToLogin();
              },
              child: Text(
                'BACK TO LOGIN',
                style: GoogleFonts.poppins(
                  color: AuthUi.tealDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 100,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const AuthHeroIcon(filled: false),
                      const SizedBox(height: 52),
                      Text(
                        'Forgot Password?',
                        textAlign: TextAlign.center,
                        style: AuthUi.titleStyle(context, size: 35),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Enter your registered email address.\nWe'll send you a password reset link.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF65707D),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 42),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!isLoading) sendResetLink();
                        },
                        decoration: AuthUi.inputDecoration(
                          context,
                          hint: 'Email Address',
                          icon: Icons.email_outlined,
                        ),
                        validator: (value) {
                          final String email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Enter your email';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      AuthPrimaryButton(
                        label: 'SEND RESET LINK',
                        leadingIcon: Icons.send_rounded,
                        loading: isLoading,
                        onPressed: isLoading ? null : sendResetLink,
                      ),
                      const SizedBox(height: 33),
                      const AuthOrDivider(),
                      const SizedBox(height: 19),
                      TextButton.icon(
                        onPressed: _goToLogin,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AuthUi.tealDark,
                        ),
                        label: Text(
                          'Back to Login',
                          style: GoogleFonts.poppins(
                            color: AuthUi.tealDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 170),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
