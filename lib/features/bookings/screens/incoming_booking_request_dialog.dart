import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/route_service.dart';
import '../../map/services/location_service.dart';
import '../models/booking_model.dart';

class IncomingBookingRequestDialog extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingBookingRequestDialog({
    super.key,
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingBookingRequestDialog> createState() =>
      _IncomingBookingRequestDialogState();
}

class _IncomingBookingRequestDialogState
    extends State<IncomingBookingRequestDialog> {
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();

  String _distanceText = "12.4 km";
  String _etaText = "28 min";

  @override
  void initState() {
    super.initState();
    _fetchRealtimeRouteDetails();
  }

  Future<void> _fetchRealtimeRouteDetails() async {
    try {
      final pickup = widget.booking.pickup.trim();
      final destination = widget.booking.destination.trim();

      if (pickup.isEmpty || destination.isEmpty) {
        if (mounted) {
          setState(() {});
        }
        return;
      }

      final pickupResults = await _locationService.getSuggestions(pickup);
      final destResults = await _locationService.getSuggestions(destination);

      if (pickupResults.isNotEmpty &&
          destResults.isNotEmpty &&
          pickupResults.first.latitude != null &&
          pickupResults.first.longitude != null &&
          destResults.first.latitude != null &&
          destResults.first.longitude != null) {
        final pickupLatLng = LatLng(
          pickupResults.first.latitude!,
          pickupResults.first.longitude!,
        );
        final destLatLng = LatLng(
          destResults.first.latitude!,
          destResults.first.longitude!,
        );

        final routeDetails = await _routeService.getRouteDetails([
          pickupLatLng,
          destLatLng,
        ]);

        if (routeDetails != null && mounted) {
          String dist = routeDetails['distanceText']?.toString() ?? '';
          if (dist.isEmpty && routeDetails['distance'] != null) {
            final double meters = (routeDetails['distance'] as num).toDouble();
            dist = '${(meters / 1000).toStringAsFixed(1)} km';
          }

          String duration = routeDetails['durationText']?.toString() ?? '';
          if (duration.isEmpty && routeDetails['duration'] != null) {
            final double sec = (routeDetails['duration'] as num).toDouble();
            duration = '${(sec / 60).round()} min';
          }

          if (dist.isNotEmpty || duration.isNotEmpty) {
            setState(() {
              if (dist.isNotEmpty) _distanceText = dist;
              if (duration.isNotEmpty) _etaText = duration;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[IncomingBookingRequestDialog] Error fetching route: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  num get _calculatedFare {
    final int seats = widget.booking.seatsBooked > 0
        ? widget.booking.seatsBooked
        : 1;
    final num basePrice = widget.booking.price;
    return basePrice * seats;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF18C7BD);
    const surfaceColor = Color(0xFF1B1D24);
    const bgColor = Color(0xFF111318);

    final booking = widget.booking;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Car Icon with Badge
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.black,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "NEW RIDE REQUEST!",
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : const Color(0xFF08234C),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "A rider is requesting a ride",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Passenger Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? surfaceColor
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Row(
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
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              booking.passengerName,
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
                                  "+91 XXXXX XXXXX",
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
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
                  const SizedBox(height: 20),
                  // Route
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Column(
                        children: [
                          Icon(
                            Icons.radio_button_checked_rounded,
                            color: Colors.greenAccent,
                            size: 18,
                          ),
                          SizedBox(height: 4),
                          Icon(
                            Icons.more_vert_rounded,
                            color: Colors.grey,
                            size: 18,
                          ),
                          SizedBox(height: 4),
                          Icon(
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
                              booking.pickup,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              "Drop",
                              style: GoogleFonts.poppins(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              booking.destination,
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats Row (Distance, ETA, Real-time Fare calculated by seat)
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    Icons.edit_road_rounded,
                    _distanceText,
                    "Distance",
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStat(
                    Icons.access_time_rounded,
                    _etaText,
                    "ETA",
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStat(
                    Icons.account_balance_wallet_rounded,
                    "₹${_calculatedFare.toStringAsFixed(1)}",
                    "Fare",
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total seats booked card (replacing Note from rider)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? surfaceColor
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF00E5FF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${booking.passengerName} request ${booking.seatsBooked} ${booking.seatsBooked == 1 ? 'seat' : 'seat'}",
                      style: GoogleFonts.poppins(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF1E293B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: widget.onReject,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      label: Text(
                        "Reject",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
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
                      onPressed: widget.onAccept,
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
            ),
            const SizedBox(height: 16),
            Row(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B1D24)
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
}
