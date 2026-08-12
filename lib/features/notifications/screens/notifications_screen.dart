import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllAsRead(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshots = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FCFC),
      appBar: AppBar(
        title: Text(
          "Notification Center",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF08234C),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _markAllAsRead(user.uid),
            icon: const Icon(Icons.done_all_rounded, size: 22),
            tooltip: "Mark all as read",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
        color: const Color(0xFF18C7BD),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('receiverId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint("Notifications Error: ${snapshot.error}");
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF18C7BD)),
              );
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No notifications yet",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We'll notify you when something happens",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = NotificationModel.fromFirestore(
                  docs[index],
                );
                return _NotificationCard(notification: notification);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationCard({required this.notification});

  String _getRelativeTime(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inSeconds < 60) return "Just now";
    if (duration.inMinutes < 60) return "${duration.inMinutes} min ago";
    if (duration.inHours < 24) return "${duration.inHours} hours ago";
    if (duration.inDays == 1) return "Yesterday";
    return DateFormat('dd MMM, hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final type = notification.type.toLowerCase();

    IconData icon = Icons.notifications_rounded;
    Color color = const Color(0xFF18C7BD);

    if (type.contains('cancel')) {
      icon = Icons.cancel_rounded;
      color = Colors.redAccent;
    } else if (type.contains('accept') ||
        type.contains('confirm') ||
        type.contains('complete')) {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
    } else if (type.contains('request')) {
      icon = Icons.person_add_rounded;
      color = Colors.blue;
    } else if (type.contains('start') || type.contains('arrive')) {
      icon = Icons.directions_car_rounded;
      color = Colors.orange;
    } else if (type.contains('chat')) {
      icon = Icons.chat_rounded;
      color = Colors.purple;
    }

    return GestureDetector(
      onTap: () async {
        if (!notification.isRead) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(notification.notificationId)
              .update({'isRead': true});
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : const Color(0xFFF1FDFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFD5F5F2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: notification.isRead ? 0.02 : 0.04,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (!notification.isRead)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w700,
                            fontSize: 15,
                            color: const Color(0xFF08234C),
                          ),
                        ),
                      ),
                      Text(
                        _getRelativeTime(notification.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.message,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
