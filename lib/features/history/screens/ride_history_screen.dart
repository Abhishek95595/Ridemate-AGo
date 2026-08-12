import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF2ED6C7);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF101116)
            : const Color(0xFFF8FCFC),
        appBar: AppBar(
          title: Text(
            'Ride History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1A1C23) : Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'COMPLETED'),
              Tab(text: 'PENDING'),
              Tab(text: 'CANCELLED'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where(
                Filter.or(
                  Filter('driverId', isEqualTo: user.uid),
                  Filter('passengerId', isEqualTo: user.uid),
                ),
              )
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data!.docs;

            return TabBarView(
              children: [
                _buildHistoryList(
                  allDocs,
                  ['completed'],
                  isDark,
                  primaryColor,
                  user.uid,
                ),
                _buildHistoryList(
                  allDocs,
                  ['pending', 'accepted', 'started'],
                  isDark,
                  primaryColor,
                  user.uid,
                ),
                _buildHistoryList(
                  allDocs,
                  ['cancelled', 'rejected'],
                  isDark,
                  primaryColor,
                  user.uid,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<String> statuses,
    bool isDark,
    Color primary,
    String currentUserId,
  ) {
    final filtered = docs.where((doc) {
      final status = doc.data()['status']?.toString().toLowerCase();
      return statuses.contains(status);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 60,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No records found',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _HistoryCard(
        data: filtered[index].data(),
        isDark: isDark,
        primaryColor: primary,
        currentUserId: currentUserId,
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final Color primaryColor;
  final String currentUserId;

  const _HistoryCard({
    required this.data,
    required this.isDark,
    required this.primaryColor,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final isDriver = data['driverId'] == currentUserId;
    final role = isDriver ? 'DRIVER' : 'PASSENGER';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C23) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  role,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            '${data['pickup'] ?? ''} → ${data['destination'] ?? ''}',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                data['date'] ?? 'N/A',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 15),
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                data['time'] ?? 'N/A',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                '₹${data['price'] ?? 0}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
      case 'rejected':
        color = Colors.redAccent;
        icon = Icons.cancel_rounded;
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.hourglass_empty_rounded;
        break;
      case 'accepted':
      case 'started':
        color = Colors.blue;
        icon = Icons.directions_car_rounded;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          status.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
