import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../app.dart';
import '../features/bookings/screens/booking_details_screen.dart';
import '../features/bookings/screens/driver_booking_requests_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/bookings/models/booking_model.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Silent background payload handler
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'ago_ride_updates';
  static const String channelName = 'AGo Ride Updates';

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      if (timeZoneName == 'Asia/Calcutta') {
        timeZoneName = 'Asia/Kolkata';
      }
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Timezone init failed: $e");
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            _handleNotificationTap(
              Map<String, dynamic>.from(jsonDecode(payload)),
            );
          } catch (e) {
            debugPrint("Failed to decode notification payload: $e");
          }
        }
      },
    );

    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'AGo ride, booking, and chat notifications.',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Save token if user is signed in
    await updateToken();

    // Listen to auth state changes to auto update token
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        updateToken();
      }
    });

    // Listen to token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveTokenToFirestore(user.uid, newToken);
      }
    });

    // Foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // Terminated state initial message
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _handleNotificationTap(initialMessage.data);
      });
    }

    _isInitialized = true;
  }

  Future<void> updateToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(user.uid, token);
      }
    } catch (e) {
      debugPrint("Error fetching/saving FCM token: $e");
    }
  }

  Future<void> _saveTokenToFirestore(String uid, String token) async {
    final docId = token.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(docId)
        .set({
          'token': token,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<void> removeCurrentTokenOnLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        final docId = token.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(docId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error removing FCM token on logout: $e');
    }
  }

  Future<void> scheduleRideAlerts(BookingModel booking) async {
    final departureTime = booking.departureTime;
    final now = DateTime.now();

    final oneHourBefore = departureTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: booking.id.hashCode + 1,
        title: 'Ride Starting Soon!',
        body: 'Your ride from ${booking.pickup} starts in 1 hour. Be ready!',
        scheduledDate: oneHourBefore,
        payload: {'bookingId': booking.id, 'type': 'ride_alert'},
      );
    }

    final thirtyMinsBefore = departureTime.subtract(
      const Duration(minutes: 30),
    );
    if (thirtyMinsBefore.isAfter(now)) {
      await _scheduleNotification(
        id: booking.id.hashCode + 2,
        title: '30 Minutes to Go!',
        body:
            'Your ride will start in 30 minutes. Make sure you are at the pickup point.',
        scheduledDate: thirtyMinsBefore,
        payload: {'bookingId': booking.id, 'type': 'ride_alert'},
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required Map<String, dynamic> payload,
  }) async {
    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode(payload),
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    String title = notification?.title ?? data['title'] ?? 'AGo Update';
    String body =
        notification?.body ??
        data['message'] ??
        data['body'] ??
        'New update received';

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(data),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final context = AGoApp.navigatorKey.currentContext;
    if (context == null) return;

    final String type = (data['type'] ?? '').toString();
    final String bookingId = (data['bookingId'] ?? '').toString();

    if (type == 'booking_request') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverBookingRequestsScreen()),
      );
    } else if (type == 'chat_message') {
      if (bookingId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bookingId: bookingId,
              otherUserName: (data['senderName'] ?? 'Driver/Passenger')
                  .toString(),
            ),
          ),
        );
      }
    } else if (bookingId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(bookingId: bookingId),
        ),
      );
    }
  }
}
