import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../history/screens/ride_history_screen.dart';
import '../../offer_ride/screens/offer_ride_screen.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF18C7BD);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    final bookings = FirebaseFirestore.instance
        .collection('bookings')
        .where('driverId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111318)
          : const Color(0xFFF9FCFC),
      appBar: AppBar(
        title: Text(
          'Control Panel',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: isDark ? Colors.white : const Color(0xFF08234C),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF08234C),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bookings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final pending = docs
              .where((d) => d.data()['status'] == 'pending')
              .length;
          final accepted = docs
              .where((d) => d.data()['status'] == 'accepted')
              .length;
          final completed = docs
              .where((d) => d.data()['status'] == 'completed')
              .length;
          final totalEarnings = docs
              .where((d) => d.data()['status'] == 'completed')
              .fold(
                0.0,
                (prev, d) =>
                    prev +
                    (double.tryParse(d.data()['price']?.toString() ?? '0') ??
                        0),
              );

          final totalKM = completed * 12.5;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEarningsCard(totalEarnings, context, isDark),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'DISTANCE',
                        '${totalKM.toStringAsFixed(1)} KM',
                        'Total distance traveled',
                        Icons.location_on,
                        const Color(0xFF14B8A6),
                        isDark,
                        true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'RIDES',
                        '$completed',
                        'Total rides completed',
                        Icons.directions_car,
                        Colors.blueAccent,
                        isDark,
                        false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildOfferRideCTA(context, primaryColor),
                const SizedBox(height: 32),
                Text(
                  'TRIP STATUS',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white70 : const Color(0xFF08234C),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusSection(pending, accepted, completed, isDark),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEarningsCard(
    double earnings,
    BuildContext context,
    bool isDark,
  ) {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B1D24), const Color(0xFF14161C)]
              : [const Color(0xFFEEFAF8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE8F0F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            top: 0,
            child: Opacity(
              opacity: isDark ? 0.2 : 0.6,
              child: Image.asset(
                'assets/images/city_silhouette.png',
                fit: BoxFit.fitHeight,
                errorBuilder: (c, e, s) => const SizedBox(),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: Image.asset(
              'assets/images/wallet_3d.png',
              width: 160,
              errorBuilder: (c, e, s) => const Icon(
                Icons.account_balance_wallet_rounded,
                size: 100,
                color: Color(0xFF14B8A6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL EARNINGS',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${earnings.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : const Color(0xFF08234C),
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Keep going! Your next ride\nis just around the corner.',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white30 : Colors.grey,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RideHistoryScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View History',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String sub,
    IconData icon,
    Color color,
    bool isDark,
    bool showPath,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D24) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white38 : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : const Color(0xFF08234C),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white30 : Colors.grey,
              fontSize: 10,
            ),
          ),
          if (showPath) ...[
            const SizedBox(height: 12),
            CustomPaint(
              size: const Size(double.infinity, 30),
              painter: _PathPainter(color),
            ),
          ],
          if (!showPath) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.directions_car, size: 40, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferRideCTA(BuildContext context, Color primary) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfferRideScreen()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFER NEW RIDE',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Start earning by offering a new ride',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(
    int pending,
    int accepted,
    int completed,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D24) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(
            'PENDING',
            '$pending',
            Colors.orange,
            Icons.assignment_late_rounded,
            isDark,
          ),
          _buildStatusItem(
            'CONFIRMED',
            '$accepted',
            Colors.green,
            Icons.check_circle_rounded,
            isDark,
          ),
          _buildStatusItem(
            'FINISHED',
            '$completed',
            Colors.blue,
            Icons.flag_rounded,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    String label,
    String val,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white38 : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : const Color(0xFF08234C),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PathPainter extends CustomPainter {
  final Color color;
  _PathPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.9,
        size.width * 0.5,
        size.height * 0.4,
      )
      ..quadraticBezierTo(size.width * 0.7, 0, size.width, size.height * 0.2);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width, size.height * 0.2),
      3,
      Paint()..color = color,
    );
    canvas.drawCircle(const Offset(0, 0), 0, Paint()); // For alignment
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
