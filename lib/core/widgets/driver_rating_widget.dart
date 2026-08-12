import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverRatingWidget extends StatelessWidget {
  final double rating;
  final int totalReviews;
  final int completedRides;
  final bool isDark;

  const DriverRatingWidget({
    super.key,
    required this.rating,
    required this.totalReviews,
    required this.completedRides,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star_rounded, color: Colors.amber, size: 16),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($totalReviews reviews)',
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$completedRides rides',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF14D8C4),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
