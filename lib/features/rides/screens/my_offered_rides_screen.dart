import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../offer_ride/screens/edit_ride_screen.dart';
import '../../offer_ride/models/ride_model.dart';

import 'package:intl/intl.dart';

class MyOfferedRidesScreen extends StatelessWidget {
  const MyOfferedRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF2ED6C7);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101116)
          : const Color(0xFFF8FCFC),
      appBar: AppBar(
        title: Text(
          'My Offered Rides',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1A1C23) : Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rides')
                  .where('driverId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return _buildEmptyState();

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _RideCard(
                    doc: docs[index],
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_filled_rounded,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No rides offered yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            'Your published rides will appear here',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isDark;
  final Color primaryColor;

  const _RideCard({
    required this.doc,
    required this.isDark,
    required this.primaryColor,
  });

  bool _isExpired(Map<String, dynamic> data) {
    try {
      final date = data['date'] as String?;
      final time = data['time'] as String?;
      if (date == null || time == null) return false;

      final format = DateFormat("d/M/yyyy h:mm a");
      final departure = format.parse("$date $time");
      return DateTime.now().isAfter(departure);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final String rawStatus = (data['status'] ?? 'active')
        .toString()
        .toLowerCase();
    final bool isExpired = _isExpired(data);

    // Automatically show as cancelled if expired and was still active
    final String displayStatus = (rawStatus == 'active' && isExpired)
        ? 'cancelled'
        : rawStatus;
    final bool canEdit = displayStatus == 'active';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C23) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
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
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${data['pickup'] ?? ''} → ${data['destination'] ?? ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _statusPill(displayStatus),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _info(Icons.calendar_today_rounded, data['date'] ?? 'N/A'),
                    const SizedBox(width: 15),
                    _info(Icons.access_time_rounded, data['time'] ?? 'N/A'),
                    const Spacer(),
                    Text(
                      '₹${data['price'] ?? 0}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (canEdit) ...[
                  _actionBtn(
                    context,
                    'EDIT',
                    Icons.edit_note_rounded,
                    Colors.blue,
                    () {
                      final ride = RideModel.fromMap(data, doc.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditRideScreen(ride: ride),
                        ),
                      );
                    },
                  ),
                  _actionBtn(
                    context,
                    'CANCEL',
                    Icons.cancel_outlined,
                    Colors.redAccent,
                    () async {
                      await doc.reference.update({'status': 'cancelled'});
                    },
                  ),
                ] else if (displayStatus == 'cancelled') ...[
                  Text(
                    isExpired ? 'EXPIRED & CANCELLED' : 'RIDE CANCELLED',
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else if (displayStatus == 'completed') ...[
                  Text(
                    'JOURNEY COMPLETED',
                    style: GoogleFonts.poppins(
                      color: Colors.blue.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
