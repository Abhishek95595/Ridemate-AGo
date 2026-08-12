import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/splash/splash_screen.dart';

class AGoApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const AGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF14B8A6);

    return MaterialApp(
      navigatorKey: AGoApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'AGo',
      themeMode: ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: const Color(0xFF00E5FF),
          surface: Colors.white,
          onSurface: const Color(0xFF0F172A),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      home: const InitialGate(),
    );
  }
}

class InitialGate extends StatelessWidget {
  const InitialGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
