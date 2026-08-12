part of '../driver_booking_requests_screen.dart';

class _DriverBookingRequestCard extends StatelessWidget {
  final GroupedBooking group;
  final bool isDark;
  final Color primaryColor;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final Future<void> Function() onVerifyPayment;

  const _DriverBookingRequestCard({
    required this.group,
    required this.isDark,
    required this.primaryColor,
    required this.onAccept,
    required this.onReject,
    required this.onStart,
    required this.onComplete,
    required this.onVerifyPayment,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF1B1D24) : Colors.white;

    // Use specific design for "pending" status to match reference image
    if (group.status == 'pending') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildCarHeader(),
            const SizedBox(height: 16),
            Text(
              "New Ride Request!",
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              "A rider is requesting a ride",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildPassengerSection(isDark),
            const SizedBox(height: 20),
            _buildRouteSection(isDark),
            const SizedBox(height: 16),
            _buildStatsRow(isDark),
            const SizedBox(height: 16),
            _buildNoteSection(isDark),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 16),
            _buildFooterInfo(),
          ],
        ),
      );
    }

    // Default style for other statuses
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blueGrey,
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.passengerName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Booked ${group.totalSeats} seat(s)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusPill(group.status),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSimpleRoute(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildSimpleActions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCarHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF14161C),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.black,
              size: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14161C)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF2ED6C7),
            child: Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Passenger",
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                ),
                Text(
                  group.passengerName,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      color: Colors.grey,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "+91 98765 XXXXX",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  "4.8",
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(
              Icons.radio_button_checked_rounded,
              color: Colors.greenAccent,
              size: 18,
            ),
            Container(
              width: 2,
              height: 24,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const Icon(
              Icons.location_on_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pickup",
                style: GoogleFonts.poppins(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                group.pickup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Drop",
                style: GoogleFonts.poppins(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                group.destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatItem(
            Icons.edit_road_rounded,
            "12.4 km",
            "Distance",
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStatItem(
            Icons.event_seat_rounded,
            "${group.totalSeats}",
            "Seats",
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStatItem(
            Icons.account_balance_wallet_rounded,
            "₹${group.totalPrice.round()}",
            "Total",
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatItem(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14161C)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14161C)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(0xFF00E5FF),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Note from rider",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Please call me when you arrive.",
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 20),
              label: Text(
                "Reject",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                "Accept",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_rounded,
          color: Colors.greenAccent,
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          "You can view details after accepting.",
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSimpleRoute() {
    return Row(
      children: [
        const Column(
          children: [
            Icon(
              Icons.radio_button_checked,
              size: 14,
              color: Color(0xFF2ED6C7),
            ),
            SizedBox(
              height: 4,
              width: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey),
              ),
            ),
            Icon(Icons.location_on, size: 14, color: Colors.redAccent),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.pickup,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                group.destination,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleActions(BuildContext context) {
    if (group.status == 'payment_pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showMyQrCode(context),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(
                'SHOW QR',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (group.status == 'accepted') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'START RIDE',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _chatButton(context),
        ],
      );
    }

    if (group.status == 'started') {
      return Row(
        children: [
          const Icon(Icons.sensors, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(
            'Live Tracking...',
            style: GoogleFonts.poppins(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          _chatButton(context),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'COMPLETE',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _chatButton(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF14D8C4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF14D8C4).withValues(alpha: 0.2),
        ),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: Color(0xFF14D8C4),
          size: 22,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                bookingId: group.bookingIds.first,
                otherUserName: group.passengerName,
                otherUserPhone:
                    '', // We don't have passenger phone in booking model usually
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusPill(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'started':
        color = Colors.blue;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      case 'payment_pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showMyQrCode(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 680),
            child: Material(
              color: isDark ? const Color(0xFF13283B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .snapshots(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                      snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          width: 320,
                          height: 360,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return SizedBox(
                          width: 320,
                          height: 300,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Could not load payment details.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  snapshot.error.toString(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text('CLOSE'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData ||
                          !snapshot.data!.exists ||
                          snapshot.data!.data() == null) {
                        return SizedBox(
                          width: 320,
                          height: 260,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person_off_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Driver profile was not found.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text('CLOSE'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final Map<String, dynamic> data = snapshot.data!.data()!;

                      final String upiId = (data['upiId'] ?? '')
                          .toString()
                          .trim();

                      final String driverName =
                          (data['name'] ?? data['displayName'] ?? 'Driver')
                              .toString()
                              .trim();

                      if (upiId.isEmpty || !upiId.contains('@')) {
                        return SizedBox(
                          width: 320,
                          height: 280,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 48,
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Valid UPI ID not found.',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please add your UPI ID in the profile section.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text('CLOSE'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final Uri upiUri = Uri(
                        scheme: 'upi',
                        host: 'pay',
                        queryParameters: <String, String>{
                          'pa': upiId,
                          'pn': driverName,
                          'am': group.totalPrice.toStringAsFixed(2),
                          'cu': 'INR',
                          'tn': 'AGo Ride Payment',
                        },
                      );

                      final String qrData = upiUri.toString();

                      bool isCompleting = false;
                      bool isRideCompleted = false;

                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Ride Payment',
                                        style: GoogleFonts.poppins(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF102A43),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ask the passenger to scan this QR',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '₹${group.totalPrice.round()}',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF14B8A6),
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: QrImageView(
                                        data: qrData,
                                        version: QrVersions.auto,
                                        size: 210,
                                        padding: EdgeInsets.zero,
                                        backgroundColor: Colors.white,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Colors.black,
                                        ),
                                        dataModuleStyle:
                                            const QrDataModuleStyle(
                                              dataModuleShape:
                                                  QrDataModuleShape.square,
                                              color: Colors.black,
                                            ),
                                        errorStateBuilder:
                                            (
                                              BuildContext context,
                                              Object? error,
                                            ) {
                                              debugPrint(
                                                'QR rendering error: $error',
                                              );
                                              return const Center(
                                                child: Text(
                                                  'Unable to generate QR',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  driverName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  upiId,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 13,
                                    color: const Color(0xFF14B8A6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'The amount is already included in the QR. '
                                  'The passenger only needs to scan and pay.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                isRideCompleted
                                    ? SizedBox(
                                        width: double.infinity,
                                        height: 64,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (dialogContext.mounted) {
                                              Navigator.of(
                                                dialogContext,
                                                rootNavigator: true,
                                              ).pop();
                                            }
                                            if (context.mounted) {
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const HomeScreen(),
                                                ),
                                                (route) => false,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF14D8C4,
                                            ),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            'Thanks 🎉 Return to Home',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _RideCompletionSwipeSlider(
                                        isDark: isDark,
                                        isVerifyingPayment: isCompleting,
                                        onVerifyPayment: () async {
                                          if (isCompleting || isRideCompleted) {
                                            return;
                                          }
                                          setDialogState(() {
                                            isCompleting = true;
                                          });

                                          try {
                                            await onVerifyPayment();

                                            if (context.mounted) {
                                              setDialogState(() {
                                                isRideCompleted = true;
                                                isCompleting = false;
                                              });
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              setDialogState(() {
                                                isCompleting = false;
                                              });

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Completion failed: $e",
                                                  ),
                                                ),
                                              );
                                            }
                                            rethrow;
                                          }
                                        },
                                        onCompletionStateChanged: (completed) {
                                          if (context.mounted && completed) {
                                            setDialogState(() {
                                              isRideCompleted = true;
                                              isCompleting = false;
                                            });
                                          }
                                        },
                                      ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          );
                        },
                      );
                    },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RideCompletionSwipeSlider extends StatefulWidget {
  final bool isDark;
  final bool isVerifyingPayment;
  final Future<void> Function() onVerifyPayment;
  final ValueChanged<bool> onCompletionStateChanged;

  const _RideCompletionSwipeSlider({
    required this.isDark,
    required this.isVerifyingPayment,
    required this.onVerifyPayment,
    required this.onCompletionStateChanged,
  });

  @override
  State<_RideCompletionSwipeSlider> createState() =>
      __RideCompletionSwipeSliderState();
}

class __RideCompletionSwipeSliderState extends State<_RideCompletionSwipeSlider>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _hasTriggered = false;
  late AnimationController _resetController;
  Animation<double>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetController.addListener(() {
      if (_resetAnimation != null) {
        setState(() {
          _dragOffset = _resetAnimation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _animateBackToStart() {
    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0);
  }

  Future<void> _handleThresholdReached(double maxDragDistance) async {
    if (_hasTriggered || widget.isVerifyingPayment) return;
    _hasTriggered = true;

    setState(() {
      _dragOffset = maxDragDistance;
    });

    try {
      await widget.onVerifyPayment();
      widget.onCompletionStateChanged(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasTriggered = false;
        });
        _animateBackToStart();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        const double handleWidth = 64.0;
        final double maxDragDistance = (totalWidth - handleWidth).clamp(
          0.0,
          totalWidth,
        );
        const double thresholdRatio = 0.65;

        return Container(
          width: totalWidth,
          height: 64,
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF111318)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF14D8C4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.only(left: 24),
                  alignment: Alignment.centerLeft,
                  child: const Row(
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'COMPLETED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: _dragOffset,
                top: 0,
                bottom: 0,
                right: -_dragOffset,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_hasTriggered || widget.isVerifyingPayment) return;
                    if (_resetController.isAnimating) {
                      _resetController.stop();
                    }

                    setState(() {
                      _dragOffset = (_dragOffset + details.delta.dx).clamp(
                        0.0,
                        maxDragDistance,
                      );
                    });

                    final double progress = maxDragDistance > 0
                        ? (_dragOffset / maxDragDistance)
                        : 0.0;

                    if (progress >= thresholdRatio) {
                      _handleThresholdReached(maxDragDistance);
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    if (_hasTriggered || widget.isVerifyingPayment) return;

                    final double progress = maxDragDistance > 0
                        ? (_dragOffset / maxDragDistance)
                        : 0.0;

                    if (progress < thresholdRatio) {
                      _animateBackToStart();
                    }
                  },
                  child: Container(
                    width: totalWidth,
                    height: 64,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1B1D24)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: widget.isVerifyingPayment
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF14D8C4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'COMPLETING RIDE...',
                                style: GoogleFonts.poppins(
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF14D8C4,
                                  ).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  color: Color(0xFF14D8C4),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'SWIPE TO COMPLETE RIDE',
                                style: GoogleFonts.poppins(
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
