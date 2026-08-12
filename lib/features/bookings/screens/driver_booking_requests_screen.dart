import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/booking_service.dart';
import '../../../services/live_location_service.dart';
import '../models/booking_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/sound_service.dart';
import '../../chat/screens/chat_screen.dart';
import '../../home/home_screen.dart';

part 'widgets/driver_booking_request_card.dart';

class GroupedBooking {
  final String passengerId;
  final String passengerName;
  final String rideId;
  final String status;
  final List<String> bookingIds;
  final int totalSeats;
  final double totalPrice;
  final String pickup;
  final String destination;
  final BookingModel originalBooking; // For easy access to non-changing fields

  GroupedBooking({
    required this.passengerId,
    required this.passengerName,
    required this.rideId,
    required this.status,
    required this.bookingIds,
    required this.totalSeats,
    required this.totalPrice,
    required this.pickup,
    required this.destination,
    required this.originalBooking,
  });
}

class DriverBookingRequestsScreen extends StatefulWidget {
  const DriverBookingRequestsScreen({super.key});

  @override
  State<DriverBookingRequestsScreen> createState() =>
      _DriverBookingRequestsScreenState();
}

class _DriverBookingRequestsScreenState
    extends State<DriverBookingRequestsScreen> {
  final BookingService _service = BookingService();
  final LiveLocationService _locationService = LiveLocationService.instance;
  static final Set<String> _shownVerifyDialogIds = {};
  final Set<String> _completedRideKeys = <String>{};
  final Set<String> _verifyingRideKeys = <String>{};

  @override
  void dispose() {
    SoundService.instance.stopSound();
    super.dispose();
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required GroupedBooking group,
    required bool accept,
  }) async {
    try {
      SoundService.instance.stopSound();
      for (var bookingId in group.bookingIds) {
        // We need the full model for the service call if possible,
        // or update service to handle ID list.
        // For now, let's update by status logic.
        final snap = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();
        final booking = BookingModel.fromDocument(snap);
        if (accept) {
          await _service.acceptBooking(booking);
        } else {
          await _service.rejectBooking(booking);
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Bookings accepted.' : 'Bookings rejected.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: accept ? Colors.green : Colors.redAccent,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    }
  }

  Future<void> _startRide(BuildContext context, GroupedBooking group) async {
    try {
      _locationService.startTrackingRide(rideId: group.rideId);
      for (var id in group.bookingIds) {
        await _service.updateBookingStatus(bookingId: id, status: 'started');
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride Started! Live tracking is active.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start ride: $e')));
    }
  }

  Future<void> _completeRide(BuildContext context, GroupedBooking group) async {
    try {
      await _locationService.stopTracking();
      for (var id in group.bookingIds) {
        await _service.initiatePaymentFlow(id);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destination reached! Awaiting passenger payment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to initiate payment: $e')));
    }
  }

  void _showVerifyPaymentDialog(BuildContext context, GroupedBooking group) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Vibrant Teal Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: const BoxDecoration(color: Color(0xFF0D8379)),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF0D8379),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Verify Payment",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Body Content Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${group.passengerName} has submitted the payment.",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Text(
                      "Total Amount",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${group.totalPrice}",
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D8379),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Soft Mint Confirmation Badge Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF9F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD1F2ED)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD1F2ED),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF0D8379),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Have you received this payment\nin your bank account?",
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F3834),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: Color(0xFF0D8379),
                            ),
                            label: Text(
                              "NOT RECEIVED",
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D8379),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF0D8379),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              for (var id in group.bookingIds) {
                                await _service.verifyPayment(
                                  bookingId: id,
                                  driverId: _service.currentUserId,
                                );
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Ride Completed Successfully! ✅",
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: Text(
                              "PAYMENT RECEIVED",
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D8379),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF18C7BD);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111318)
          : const Color(0xFFF8FCFC),
      appBar: AppBar(
        title: Text(
          'Booking Requests',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1B1D24) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: _service.getDriverRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allBookings = snapshot.data!;
          if (allBookings.isEmpty) return _buildEmptyState(isDark);

          // --- GROUPING LOGIC ---
          final Map<String, GroupedBooking> groupedMap = {};
          for (var b in allBookings) {
            final key = '${b.passengerId}_${b.rideId}_${b.status}';
            if (groupedMap.containsKey(key)) {
              final existing = groupedMap[key]!;
              groupedMap[key] = GroupedBooking(
                passengerId: existing.passengerId,
                passengerName: existing.passengerName,
                rideId: existing.rideId,
                status: existing.status,
                bookingIds: [...existing.bookingIds, b.id],
                totalSeats: existing.totalSeats + b.seatsBooked,
                totalPrice: existing.totalPrice + b.totalPrice.toDouble(),
                pickup: existing.pickup,
                destination: existing.destination,
                originalBooking: existing.originalBooking,
              );
            } else {
              groupedMap[key] = GroupedBooking(
                passengerId: b.passengerId,
                passengerName: b.passengerName,
                rideId: b.rideId,
                status: b.status,
                bookingIds: [b.id],
                totalSeats: b.seatsBooked,
                totalPrice: b.totalPrice.toDouble(),
                pickup: b.pickup,
                destination: b.destination,
                originalBooking: b,
              );
            }
          }
          final groupedList = groupedMap.values.toList();

          // Real-time payment verification check for groups
          for (final group in groupedList) {
            final String groupKey = group.bookingIds.join('_');
            if (group.originalBooking.paymentStatus ==
                    'submitted_by_passenger' &&
                group.status == 'payment_pending' &&
                !_shownVerifyDialogIds.contains(groupKey)) {
              _shownVerifyDialogIds.add(groupKey);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showVerifyPaymentDialog(context, group);
              });
            }
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: groupedList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final group = groupedList[index];
              return _DriverBookingRequestCard(
                group: group,
                isDark: isDark,
                primaryColor: primaryColor,
                onAccept: () =>
                    _confirmAction(context, group: group, accept: true),
                onReject: () =>
                    _confirmAction(context, group: group, accept: false),
                onStart: () => _startRide(context, group),
                onComplete: () => _completeRide(context, group),
                onVerifyPayment: () async {
                  final String rideKey = group.bookingIds.join('_');

                  if (_completedRideKeys.contains(rideKey) ||
                      _verifyingRideKeys.contains(rideKey)) {
                    return;
                  }

                  _verifyingRideKeys.add(rideKey);

                  try {
                    for (var id in group.bookingIds) {
                      await _service.verifyPayment(
                        bookingId: id,
                        driverId: _service.currentUserId,
                      );
                    }

                    if (mounted) {
                      setState(() {
                        _completedRideKeys.add(rideKey);
                      });
                    }
                  } finally {
                    _verifyingRideKeys.remove(rideKey);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No requests yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            'Passenger requests will appear here',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
