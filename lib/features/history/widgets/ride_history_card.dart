import 'package:flutter/material.dart';

import '../models/ride_history_model.dart';

class RideHistoryCard extends StatelessWidget {
  const RideHistoryCard({super.key, required this.ride});

  final RideHistoryModel ride;

  Color _statusColor(BuildContext context) {
    switch (ride.status.toLowerCase()) {
      case 'completed':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon() {
    switch (ride.status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;

      case 'cancelled':
        return Icons.cancel;

      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _statusColor(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.pickup,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.only(left: 11),
              child: Icon(Icons.arrow_downward),
            ),

            Row(
              children: [
                const Icon(Icons.flag, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.destination,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(ride.date),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text(ride.time),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.airline_seat_recline_normal, size: 18),
                const SizedBox(width: 8),
                Text("${ride.seats} Seat(s)"),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.currency_rupee, size: 18),
                const SizedBox(width: 8),
                Text(
                  ride.price.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const Divider(height: 24),

            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(), color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      ride.status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
