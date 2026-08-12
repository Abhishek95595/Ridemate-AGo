part of '../find_ride_screen.dart';

class _FindRideCard extends StatefulWidget {
  final RideModel ride;
  final double distance;
  final bool isDark;
  final bool isBooking;
  final int selectedSeats;
  final int alreadyBooked;
  final Function(int) onSeatsChanged;
  final VoidCallback onBook;

  const _FindRideCard({
    required this.ride,
    required this.distance,
    required this.isDark,
    required this.isBooking,
    required this.selectedSeats,
    this.alreadyBooked = 0,
    required this.onSeatsChanged,
    required this.onBook,
  });

  @override
  State<_FindRideCard> createState() => _FindRideCardState();
}

class _FindRideCardState extends State<_FindRideCard> {
  bool _isExpanded = false;

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final availableSeats = widget.ride.availableSeats;
    final totalPrice = widget.ride.price * widget.selectedSeats;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1B1D24) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
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
          Row(
            children: [
              AppAvatar(
                avatarIndex: widget.ride.driverAvatarIndex,
                photoUrl: widget.ride.driverPhotoUrl,
                size: 60,
                borderColor: const Color(0xFF14D8C4),
                borderWidth: 1.2,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.ride.driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (widget.ride.driverVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Color(0xFF14D8C4),
                          ),
                        ],
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF14D8C4),
                          ),
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.ride.driverRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark
                                ? Colors.white60
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.ride.vehicle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: widget.isDark
                                  ? Colors.white60
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.ride.vehicleNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${totalPrice.round()}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: const Color(0xFF00BFA5),
                    ),
                  ),
                  Text(
                    '₹${widget.ride.price}/seat',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F8F7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DriverRatingWidget(
                    rating: widget.ride.driverRating,
                    totalReviews: widget.ride.driverTotalReviews,
                    completedRides: widget.ride.driverCompletedRides,
                    isDark: widget.isDark,
                  ),
                  const SizedBox(height: 15),
                  Divider(
                    color: widget.isDark ? Colors.white10 : Colors.grey[200],
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Confirmed Passengers',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('rideId', isEqualTo: widget.ride.id)
                        .where(
                          'status',
                          whereIn: [
                            'accepted',
                            'confirmed',
                            'started',
                            'completed',
                            'payment_pending',
                          ],
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Text(
                          'No passengers confirmed yet',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: docs.map((doc) {
                          final name = doc.data()['passengerName'] ?? 'Rider';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF14D8C4,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  size: 12,
                                  color: Color(0xFF14D8C4),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF14D8C4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (widget.alreadyBooked > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF14D8C4).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF009688),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'You have already booked ${widget.alreadyBooked} seat(s).',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00796B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildRouteInfo(),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoChip(Icons.calendar_today_rounded, widget.ride.date),
              _infoChip(Icons.access_time_rounded, widget.ride.time),
              _infoChip(Icons.event_seat_rounded, '$availableSeats Left'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(
                Icons.location_on_rounded,
                _formatDistance(widget.distance),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF14D8C4).withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_rounded,
                        size: 26,
                        color: Color(0xFF14D8C4),
                      ),
                      onPressed: widget.selectedSeats > 1
                          ? () =>
                                widget.onSeatsChanged(widget.selectedSeats - 1)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${widget.selectedSeats}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: widget.isDark
                              ? Colors.white
                              : const Color(0xFF08234C),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_rounded,
                        size: 26,
                        color: Color(0xFF14D8C4),
                      ),
                      onPressed: widget.selectedSeats < availableSeats
                          ? () =>
                                widget.onSeatsChanged(widget.selectedSeats + 1)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14D8C4), Color(0xFF08BFA5)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF14D8C4,
                          ).withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: widget.isBooking || availableSeats == 0
                          ? null
                          : widget.onBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                      ),
                      child: widget.isBooking
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : Text(
                              'BOOK SEATS',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Row(
      children: [
        Column(
          children: [
            const Icon(
              Icons.radio_button_checked,
              size: 16,
              color: Color(0xFF14D8C4),
            ),
            Container(
              height: 35,
              width: 2,
              color: const Color(0xFF14D8C4).withValues(alpha: 0.2),
            ),
            const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.ride.pickup,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 25),
              Text(
                widget.ride.destination,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
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

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14D8C4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF14D8C4)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF14D8C4),
            ),
          ),
        ],
      ),
    );
  }
}
