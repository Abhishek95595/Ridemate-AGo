import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/home/home_screen.dart';
import '../../services/auth_providers.dart';
import '../../services/google_auth_service.dart';
import '../../services/notification_service.dart';
import '../fogot_password/forgot_password_screen.dart';
import '../otp/phone_login_screen.dart';
import '../signup/signup_screen.dart';
import '../widgets/auth_ui.dart';
import '../verify/email_verification_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signIn(
        emailController.text.trim(),
        passwordController.text,
      );

      final user = userCredential.user;

      if (user != null) {
        await authService.reloadUser();

        // Refresh FCM Token on Login
        await NotificationService.instance.updateToken();

        if (!mounted) return;

        if (!user.emailVerified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(email: user.email ?? ''),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = _getFirebaseAuthErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      default:
        return e.message ?? 'Login failed. Please check your credentials.';
    }
  }

  Future<void> googleLogin() async {
    final user = await GoogleAuthService.signInWithGoogle();
    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google Sign-In cancelled')));
      return;
    }

    // Refresh FCM Token on Social Login
    await NotificationService.instance.updateToken();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
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
                      const AuthHeroIcon(),
                      const SizedBox(height: 28),
                      Text(
                        'Welcome 👋',
                        textAlign: TextAlign.center,
                        style: AuthUi.titleStyle(context, size: 35),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Login to continue your AGo journey',
                        textAlign: TextAlign.center,
                        style: AuthUi.subtitleStyle(context),
                      ),
                      const SizedBox(height: 34),
                      TextFormField(
                        controller: emailController,
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
                          if (!email.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!isLoading) login();
                        },
                        decoration: AuthUi.inputDecoration(
                          context,
                          hint: 'Password',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
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
                          if (value == null || value.isEmpty) {
                            return 'Enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            activeColor: AuthUi.teal,
                            side: const BorderSide(
                              color: AuthUi.tealDark,
                              width: 1.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                            onChanged: (value) {
                              setState(() => rememberMe = value ?? false);
                            },
                          ),
                          Text(
                            'Remember Me',
                            style: GoogleFonts.poppins(
                              color: AuthUi.navy,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AuthPrimaryButton(
                        label: 'LOGIN',
                        loading: isLoading,
                        onPressed: isLoading ? null : login,
                      ),
                      const SizedBox(height: 23),
                      const AuthOrDivider(),
                      const SizedBox(height: 22),
                      AuthOutlineButton(
                        icon: Text(
                          'G',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF4285F4),
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        label: 'Continue with Google',
                        onPressed: googleLogin,
                      ),
                      const SizedBox(height: 14),
                      AuthOutlineButton(
                        icon: const Icon(
                          Icons.phone_android_rounded,
                          color: AuthUi.tealDark,
                        ),
                        label: 'Continue with Phone',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PhoneLoginScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.poppins(
                            color: AuthUi.tealDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            "Don’t have an account?",
                            style: TextStyle(
                              color: Color(0xFF65707D),
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.poppins(
                                color: AuthUi.tealDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 110),
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
