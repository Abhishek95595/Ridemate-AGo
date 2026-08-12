import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthUi {
  static const Color teal = Color(0xFF12B8A7);
  static const Color tealDark = Color(0xFF009D91);
  static const Color navy = Color(0xFF071B3A);
  static const Color mint = Color(0xFFE8F8F5);
  static const Color page = Color(0xFFF8FCFC);

  static TextStyle titleStyle(BuildContext context, {double size = 34}) {
    return GoogleFonts.poppins(
      color: navy,
      fontSize: size,
      height: 1.12,
      letterSpacing: -1,
      fontWeight: FontWeight.w800,
    );
  }

  static TextStyle subtitleStyle(BuildContext context) {
    return GoogleFonts.poppins(
      color: const Color(0xFF65707D),
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    const Color border = Color(0xFFCDE8E4);

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: const Color(0xFF8B939C),
        fontSize: 15,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 66),
      prefixIcon: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF9F6),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: tealDark),
        ),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      errorStyle: GoogleFonts.poppins(
        color: const Color(0xFFFF6B6B),
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: border, width: 1.15),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: teal, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.8),
      ),
    );
  }
}

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuthUi.page,
      child: Stack(
        children: [
          Positioned(
            top: -135,
            right: -125,
            child: Container(
              width: 330,
              height: 330,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F7F4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 155,
            child: CustomPaint(painter: _AuthRoadPainter()),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class AuthTopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const AuthTopButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon, color: AuthUi.navy, size: 27),
          ),
        ),
      ),
    );
  }
}

class AuthHeroIcon extends StatelessWidget {
  final bool filled;

  const AuthHeroIcon({super.key, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white, // Match white auth page theme
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/app_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.directions_car_rounded,
            color: Color(0xFF008E83),
            size: 80,
          );
        },
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(
                  colors: [Color(0xFF8CCDC5), Color(0xFF77BDB5)],
                )
              : const LinearGradient(
                  colors: [Color(0xFF19BFB0), Color(0xFF08A899)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: AuthUi.teal.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 25,
                  height: 25,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, size: 23),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 12),
                      Icon(trailingIcon, size: 24),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const Color line = Color(0xFFD5E4E2);

    return Row(
      children: [
        const Expanded(child: Divider(color: line)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: AuthUi.mint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'OR',
            style: TextStyle(
              color: Color(0xFF43505C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: line)),
      ],
    );
  }
}

class AuthOutlineButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const AuthOutlineButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(
            color: AuthUi.navy,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDCEAE8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _AuthRoadPainter extends CustomPainter {
  const _AuthRoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint hillPaint = Paint()..color = const Color(0xFFE2F5F1);
    final Paint backHillPaint = Paint()..color = const Color(0xFFECF9F6);
    final Paint roadPaint = Paint()..color = Colors.white;

    final Path backHill = Path()
      ..moveTo(0, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.17,
        size.width * 0.45,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.72,
        size.width,
        size.height * 0.31,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(backHill, backHillPaint);

    final Path hill = Path()
      ..moveTo(0, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.42,
        size.width * 0.53,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.95,
        size.width,
        size.height * 0.56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, hillPaint);

    final Path road = Path()
      ..moveTo(size.width * 0.50, size.height)
      ..cubicTo(
        size.width * 0.41,
        size.height * 0.76,
        size.width * 0.66,
        size.height * 0.64,
        size.width * 0.55,
        size.height * 0.46,
      )
      ..cubicTo(
        size.width * 0.50,
        size.height * 0.37,
        size.width * 0.47,
        size.height * 0.31,
        size.width * 0.51,
        size.height * 0.26,
      )
      ..lineTo(size.width * 0.57, size.height * 0.26)
      ..cubicTo(
        size.width * 0.53,
        size.height * 0.34,
        size.width * 0.62,
        size.height * 0.41,
        size.width * 0.63,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.7,
        size.width * 0.60,
        size.height * 0.85,
        size.width * 0.66,
        size.height,
      )
      ..close();
    canvas.drawPath(road, roadPaint);
  }

  @override
  bool shouldRepaint(covariant _AuthRoadPainter oldDelegate) => false;
}
