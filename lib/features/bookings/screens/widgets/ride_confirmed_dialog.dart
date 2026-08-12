import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/notification_service.dart';
import '../../models/booking_model.dart';

class RideConfirmedDialog extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onViewBooking;

  const RideConfirmedDialog({
    super.key,
    required this.booking,
    required this.onViewBooking,
  });

  @override
  Widget build(BuildContext context) {
    // Schedule local alerts when this dialog is shown (meaning the ride is accepted)
    NotificationService.instance.scheduleRideAlerts(booking);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF18C7BD);
    final surfaceColor = isDark ? const Color(0xFF1B1D24) : Colors.white;

    final driverData = booking.driverDetails;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: surfaceColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Success Icon
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF14D8C4).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF14D8C4),
                size: 52,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "🎉 Ride Confirmed!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF08234C),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Your ride request has been accepted.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),

            // Details List
            _buildDetailItem(
              Icons.person_outline_rounded,
              "Driver",
              (driverData['name'] ?? '').toString().trim().isNotEmpty
                  ? (driverData['name'] ?? '').toString().trim()
                  : 'AGo Driver',
              isDark,
            ),
            _buildDetailItem(
              Icons.directions_car_outlined,
              "Vehicle",
              _getVehicleText(driverData),
              isDark,
            ),
            _buildDetailItem(
              Icons.pin_outlined,
              "Vehicle No",
              _getVehicleNumberText(driverData),
              isDark,
            ),
            _buildDetailItem(
              Icons.calendar_month_outlined,
              "Date",
              booking.date.isNotEmpty ? booking.date : 'Scheduled',
              isDark,
            ),
            _buildDetailItem(
              Icons.access_time_rounded,
              "Time",
              booking.time.isNotEmpty ? booking.time : 'Scheduled',
              isDark,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, thickness: 0.5),
            ),

            _buildRouteItem(
              Icons.radio_button_checked,
              "Pickup",
              booking.pickup,
              const Color(0xFF14D8C4),
              isDark,
            ),
            const SizedBox(height: 16),
            _buildRouteItem(
              Icons.location_on,
              "Drop",
              booking.destination,
              Colors.redAccent,
              isDark,
            ),

            const SizedBox(height: 34),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "CLOSE",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                        letterSpacing: 1,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onViewBooking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "VIEW BOOKING",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getVehicleText(Map<String, dynamic> driverData) {
    final color = (driverData['vehicleColor'] ?? '').toString().trim();
    final model = (driverData['vehicleModel'] ?? driverData['vehicle'] ?? '')
        .toString()
        .trim();
    final type = (driverData['vehicleType'] ?? '').toString().trim();

    final List<String> parts = [];
    if (color.isNotEmpty) parts.add(color);
    if (model.isNotEmpty) parts.add(model);
    if (parts.isEmpty && type.isNotEmpty) parts.add(type);
    if (parts.isEmpty) return 'Standard Vehicle';
    return parts.join(' ');
  }

  String _getVehicleNumberText(Map<String, dynamic> driverData) {
    final num = (driverData['vehicleNumber'] ?? '').toString().trim();
    if (num.isEmpty) return 'Not Provided';
    return num;
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF14D8C4), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF08234C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteItem(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF08234C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
