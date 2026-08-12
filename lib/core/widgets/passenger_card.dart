import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_avatar.dart';

class PassengerCard extends StatelessWidget {
  final String passengerId;
  final String passengerName;
  final String? photoUrl;
  final int? avatarIndex;
  final int seatsBooked;
  final String driverId;
  final bool isDark;

  const PassengerCard({
    super.key,
    required this.passengerId,
    required this.passengerName,
    this.photoUrl,
    this.avatarIndex,
    required this.seatsBooked,
    required this.driverId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(avatarIndex: avatarIndex, photoUrl: photoUrl, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passengerName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '$seatsBooked seat(s) booked',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('passengerId', isEqualTo: passengerId)
                .where('driverId', isEqualTo: driverId)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snapshot) {
              final previousRides = snapshot.data?.docs.length ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'History',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$previousRides ride${previousRides == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF14D8C4),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
