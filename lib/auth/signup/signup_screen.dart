import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constant/app_links.dart';
import '../../services/auth_providers.dart';
import '../login/login_screen.dart';
import '../widgets/auth_ui.dart';
import '../verify/email_verification_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptTerms = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!acceptTerms) {
      _showMessage('Please accept the Terms & Conditions.', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final String name = nameController.text.trim();
      final String email = emailController.text.trim();
      final String password = passwordController.text;

      final userCredential = await authService.signUp(
        email: email,
        password: password,
        name: name,
      );

      final user = userCredential.user;

      if (user != null) {
        if (!mounted) return;
        _showMessage(
          'Account created! Please verify your email.',
          isError: false,
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_getFirebaseAuthMessage(error), isError: true);
    } catch (error) {
      debugPrint('Signup error: $error');
      _showMessage('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getFirebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Please use a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password signup is not enabled in Firebase.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Account creation failed.';
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 42),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const AuthHeroIcon(),
                const SizedBox(height: 24),
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: AuthUi.titleStyle(context, size: 34),
                ),
                const SizedBox(height: 7),
                Text(
                  'Join AGo and start sharing rides',
                  textAlign: TextAlign.center,
                  style: AuthUi.subtitleStyle(context),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: nameController,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: AuthUi.inputDecoration(
                    context,
                    hint: 'Full Name',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    final String name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Enter your full name';
                    if (name.length < 3) {
                      return 'Name must contain at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: AuthUi.inputDecoration(
                    context,
                    hint: 'Email Address',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    final String email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter your email';
                    final RegExp pattern = RegExp(
                      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                    );
                    if (!pattern.hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: AuthUi.inputDecoration(
                    context,
                    hint: '10-digit Phone Number',
                    icon: Icons.phone_outlined,
                  ).copyWith(counterText: ''),
                  validator: (value) {
                    final String phone = value?.trim() ?? '';
                    if (phone.isEmpty) return 'Enter your phone number';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                      return 'Enter a valid Indian phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordController,
                  enabled: !isLoading,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: AuthUi.inputDecoration(
                    context,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthUi.tealDark,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final String password = value ?? '';
                    if (password.isEmpty) return 'Enter your password';
                    if (password.length < 6) {
                      return 'Password must contain at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmPasswordController,
                  enabled: !isLoading,
                  obscureText: obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) {
                    if (!isLoading) signUp();
                  },
                  decoration: AuthUi.inputDecoration(
                    context,
                    hint: 'Confirm Password',
                    icon: Icons.lock_reset_outlined,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthUi.tealDark,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your password';
                    }
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Checkbox(
                      value: acceptTerms,
                      activeColor: AuthUi.teal,
                      side: const BorderSide(
                        color: AuthUi.tealDark,
                        width: 1.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      onChanged: isLoading
                          ? null
                          : (value) {
                              setState(() => acceptTerms = value ?? false);
                            },
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF65707D),
                            fontSize: 13.5,
                          ),
                          children: [
                            const TextSpan(text: 'I accept the '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: const TextStyle(
                                color: AuthUi.tealDark,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(termsOfServiceUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: AuthUi.tealDark,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(privacyPolicyUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AuthPrimaryButton(
                  label: 'CREATE ACCOUNT',
                  loading: isLoading,
                  onPressed: isLoading ? null : signUp,
                ),
                const SizedBox(height: 18),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: Color(0xFF65707D),
                        fontSize: 13.5,
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                      child: Text(
                        'Login',
                        style: GoogleFonts.poppins(
                          color: AuthUi.tealDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 105),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
