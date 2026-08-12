import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../rides/screens/my_offered_rides_screen.dart';
import 'create_ride_screen.dart';

class OfferRideScreen extends StatelessWidget {
  const OfferRideScreen({super.key});

  static const Color _teal = Color(0xFF16BDB5);
  static const Color _navy = Color(0xFF08234C);
  static const Color _mint = Color(0xFFE8FAF7);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark
        ? const Color(0xFF07172C)
        : const Color(0xFFF9FCFC);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF102437) : _mint,
        foregroundColor: isDark ? Colors.white : _navy,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Offer Ride',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.08 : 0.34,
                child: Image.asset(
                  'assets/images/ride_group_hero1.png',
                  height: 130,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to Share Your Ride?',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : _navy,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Manage your rides from one place.',
                  style: GoogleFonts.poppins(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : _navy.withValues(alpha: 0.72),
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColorFiltered(
                    colorFilter: isDark
                        ? ColorFilter.mode(
                            const Color(0xFF07172C).withValues(alpha: 0.34),
                            BlendMode.darken,
                          )
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.srcOver,
                          ),
                    child: Image.asset(
                      'assets/images/ride_group_hero1.png',
                      width: double.infinity,
                      height: 225,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionCard(
                  context,
                  icon: Icons.person_add_alt_1_rounded,
                  smallIcon: Icons.directions_car_filled_rounded,
                  title: 'Offer New Ride',
                  subtitle: 'Create and publish a ride',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateRideScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _buildOptionCard(
                  context,
                  icon: Icons.directions_car_filled_rounded,
                  smallIcon: Icons.format_list_bulleted_rounded,
                  title: 'My Offered Rides',
                  subtitle: 'View all your rides',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyOfferedRidesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required IconData smallIcon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 118,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13283B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFCDE9E6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.07),
                blurRadius: 13,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 69,
                height: 69,
                decoration: BoxDecoration(
                  color: isDark
                      ? _teal.withValues(alpha: 0.13)
                      : const Color(0xFFE4F8F5),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 38, color: isDark ? _teal : _navy),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Icon(
                        smallIcon,
                        size: 18,
                        color: isDark ? _teal : _navy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.58)
                            : _navy.withValues(alpha: 0.72),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
