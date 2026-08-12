import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String? rideId;
  final String? senderId;
  final String? bookingId;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.rideId,
    this.senderId,
    this.bookingId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      userId: data['receiverId'] ?? data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      rideId: data['rideId'],
      senderId: data['senderId'],
      bookingId: data['bookingId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiverId': userId,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'rideId': rideId,
      'senderId': senderId,
      'bookingId': bookingId,
    };
  }
}
