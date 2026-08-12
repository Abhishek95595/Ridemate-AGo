import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isVideoReady = false;
  bool _hasNavigated = false;
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    _initializeVideo();

    // Set a timeout for fallback UI if video takes too long or fails
    Future.delayed(const Duration(seconds: 4), () {
      if (!_isVideoReady && mounted) {
        setState(() => _showFallback = true);
        _fadeController.forward();

        // Auto-navigate after 2 more seconds if still on splash
        Future.delayed(const Duration(seconds: 2), _openWelcomeScreen);
      }
    });
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        'assets/videos/ago_animation.mp4',
      );

      _videoController = controller;

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);

      controller.addListener(_videoListener);

      if (!mounted) return;

      setState(() {
        _isVideoReady = true;
      });

      await controller.play();
      _fadeController.forward();
    } catch (error) {
      debugPrint('Splash video error: $error');
      if (mounted) {
        setState(() => _showFallback = true);
        _fadeController.forward();
        Future.delayed(const Duration(seconds: 2), _openWelcomeScreen);
      }
    }
  }

  void _videoListener() {
    final controller = _videoController;

    if (controller == null ||
        !controller.value.isInitialized ||
        _hasNavigated) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;

    if (duration <= Duration.zero) {
      return;
    }

    // Navigate slightly before video ends for smoother transition
    final videoCompleted =
        position >= duration - const Duration(milliseconds: 300);

    if (videoCompleted) {
      _openWelcomeScreen();
    }
  }

  void _openWelcomeScreen() {
    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_videoListener);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF14B8A6);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Matches app's dark background
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isVideoReady && _videoController != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),

              // Fallback UI or Logo overlay
              if (_showFallback || !_isVideoReady)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/app_logo.png',
                      width: 120,
                      height: 120,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.directions_car_filled_rounded,
                        color: primaryColor,
                        size: 80,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AGo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RIDE TOGETHER',
                      style: TextStyle(
                        color: primaryColor.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
