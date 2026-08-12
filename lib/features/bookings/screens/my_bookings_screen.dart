import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/booking_service.dart';
import '../models/booking_model.dart';
import 'booking_details_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  static const Color _teal = Color(0xFF16BDB5);
  static const Color _navy = Color(0xFF08234C);
  static const Color _mint = Color(0xFFE8FAF7);

  final BookingService _service = BookingService();

  Future<void> _callDriver(BuildContext context, String phone) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone is unavailable.')),
      );
      return;
    }

    final Uri uri = Uri.parse('tel:$phone');
    if (!await launchUrl(uri)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open dialer.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111318)
          : const Color(0xFFF9FCFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1B1D24) : _mint,
        foregroundColor: isDark ? Colors.white : _navy,
        centerTitle: true,
        elevation: 0,
        title: Text(
          'My Bookings',
          style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: ColorFiltered(
              colorFilter: isDark
                  ? ColorFilter.mode(
                      const Color(0xFF111318).withValues(alpha: 0.38),
                      BlendMode.darken,
                    )
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.srcOver,
                    ),
              child: Image.asset(
                'assets/images/ride_group_hero1.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<BookingModel>>(
              stream: _service.getPassengerBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _teal),
                  );
                }

                final List<BookingModel> bookings =
                    snapshot.data ?? <BookingModel>[];

                if (bookings.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final BookingModel booking = bookings[index];
                    return _BookingCard(
                      booking: booking,
                      isDark: isDark,
                      onCall: (phone) => _callDriver(context, phone),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: isDark ? _teal.withValues(alpha: 0.12) : _mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: _teal,
                size: 47,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'No bookings found',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : _navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Your booked rides will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white54 : Colors.grey,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  static const Color _teal = Color(0xFF16BDB5);
  static const Color _navy = Color(0xFF08234C);
  static const Color _mint = Color(0xFFE8FAF7);
  static const Color _coral = Color(0xFFFF625A);

  final BookingModel booking;
  final bool isDark;
  final ValueChanged<String> onCall;

  const _BookingCard({
    required this.booking,
    required this.isDark,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> details = booking.driverDetails;
    final String status = booking.status.toLowerCase();
    final bool isActive =
        status == 'accepted' || status == 'started' || status == 'arrived';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isActive) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingDetailsScreen(bookingId: booking.id),
              ),
            );
          } else {
            _showRideSummary(context);
          }
        },
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1D24) : Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFCDE8E5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 13,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${booking.pickup}  →  ${booking.destination}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : _navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isActive ? Icons.map_outlined : Icons.receipt_long_outlined,
                    color: isActive ? _teal : _coral,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Status:',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : _navy,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _statusPill(booking.status),
                    ],
                  ),
                  Text(
                    '₹${booking.totalPrice}',
                    style: GoogleFonts.poppins(
                      color: _teal,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(booking.driverId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final driverData = snapshot.data?.data() ?? details;
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: _teal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (driverData['name'] ?? 'Driver').toString(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "${driverData['vehicleColor'] ?? ''} ${driverData['vehicleModel'] ?? driverData['vehicle'] ?? ''} • ${driverData['vehicleNumber'] ?? ''}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "TAP FOR MAP",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _teal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              if (!isActive &&
                  (booking.date.isNotEmpty || booking.time.isNotEmpty)) ...[
                const SizedBox(height: 11),
                Wrap(
                  spacing: 10,
                  runSpacing: 7,
                  children: [
                    if (booking.date.isNotEmpty)
                      _smallInfo(Icons.calendar_month_outlined, booking.date),
                    if (booking.time.isNotEmpty)
                      _smallInfo(Icons.access_time_rounded, booking.time),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRideSummary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1B1D24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(booking.driverId)
            .snapshots(),
        builder: (context, snapshot) {
          final driverData = snapshot.data?.data() ?? booking.driverDetails;
          return Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Ride Summary",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _navy,
                      ),
                    ),
                    _statusPill(booking.status),
                  ],
                ),
                const SizedBox(height: 25),
                _summaryRow(
                  "Driver Name",
                  (driverData['name'] ?? 'Driver').toString(),
                  Icons.person_outline,
                ),
                const SizedBox(height: 15),
                _summaryRow(
                  "Vehicle",
                  "${driverData['vehicleColor'] ?? ''} ${driverData['vehicleModel'] ?? driverData['vehicle'] ?? ''}",
                  Icons.directions_car_outlined,
                ),
                const SizedBox(height: 15),
                _summaryRow(
                  "Vehicle Number",
                  (driverData['vehicleNumber'] ?? 'N/A').toString(),
                  Icons.pin_outlined,
                ),
                const SizedBox(height: 15),
                _summaryRow(
                  "Starting Point",
                  booking.pickup,
                  Icons.radio_button_checked,
                  color: _teal,
                ),
                const SizedBox(height: 15),
                _summaryRow(
                  "Destination",
                  booking.destination,
                  Icons.location_on,
                  color: _coral,
                ),
                const SizedBox(height: 25),
                const Divider(),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Payment Amount",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    Text(
                      "₹${booking.totalPrice}",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "Payment via UPI Direct to Driver",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      "DONE",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : _navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? _teal.withValues(alpha: 0.11) : _mint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isDark ? _teal : _navy, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : _navy,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final String normalized = status.toLowerCase();
    late final Color color;
    late final IconData icon;

    switch (normalized) {
      case 'accepted':
      case 'started':
      case 'arrived':
        color = _teal;
        icon = Icons.verified_rounded;
        break;
      case 'rejected':
      case 'cancelled':
        color = _coral;
        icon = Icons.cancel_rounded;
        break;
      case 'completed':
        color = const Color(0xFF4CB7B1);
        icon = Icons.check_circle_outline_rounded;
        break;
      default:
        color = const Color(0xFFFFA726);
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }
}
