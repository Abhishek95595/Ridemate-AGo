import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/home_screen.dart';
import '../../services/auth_providers.dart';
import '../widgets/auth_ui.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _verificationCheckTimer;
  int _seconds = 60;
  bool _canResend = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _startVerificationCheckTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerificationStatus(silent: true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  void _startVerificationCheckTimer() {
    _verificationCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkVerificationStatus(silent: true);
    });
  }

  Future<void> _checkVerificationStatus({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.reloadUser();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        _verificationCheckTimer?.cancel();
        await authService.updateFirestoreVerificationStatus();

        if (!mounted) return;
        if (!silent) {
          _showMessage('Email verified successfully!', isError: false);
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else if (!silent) {
        _showMessage(
          'Email is not verified yet. Open Gmail and click the verification link.',
        );
      }
    } catch (e) {
      if (!silent) _showMessage('Verification check failed. Please try again.');
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      _startTimer();
      _showMessage(
        'Verification email sent to ${widget.email}',
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _showMessage('Too many requests. Please wait a while and try again.');
      } else {
        _showMessage(e.message ?? 'Failed to resend verification email.');
      }
    } catch (e) {
      _showMessage('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      _showMessage('Sign out failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: Column(
            children: [
              const AuthHeroIcon(),
              const SizedBox(height: 25),
              Text(
                "Verify Your Email",
                style: AuthUi.titleStyle(context, size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                "We sent a verification link to your email.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF65707D), fontSize: 15),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AuthUi.teal.withValues(alpha: 0.2)),
                ),
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    color: AuthUi.tealDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AuthPrimaryButton(
                label: 'I HAVE VERIFIED MY EMAIL',
                loading: _isLoading,
                onPressed: _isLoading ? null : () => _checkVerificationStatus(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: (_canResend && !_isLoading)
                      ? _resendVerification
                      : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    _canResend
                        ? "Resend Verification Email"
                        : "Resend in 00:${_seconds.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AuthUi.tealDark,
                    side: const BorderSide(color: AuthUi.teal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: _isLoading ? null : _signOut,
                child: const Text(
                  "Change Email / Sign Out",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
