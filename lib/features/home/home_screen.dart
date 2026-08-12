import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

import '../../auth/login/login_screen.dart';
import '../../core/widgets/app_avatar.dart';
import '../bookings/screens/booking_details_screen.dart';
import '../bookings/screens/driver_booking_requests_screen.dart';
import '../bookings/screens/my_bookings_screen.dart';
import '../dashboard/screens/driver_dashboard_screen.dart';
import '../find_ride/find_ride_screen.dart';
import '../history/screens/ride_history_screen.dart';
import '../map/providers/location_provider.dart';
import '../offer_ride/screens/offer_ride_screen.dart';
import '../profile/screen/profile_screen.dart';
import '../rides/screens/my_offered_rides_screen.dart';
import '../bookings/screens/widgets/ride_confirmed_dialog.dart';
import '../bookings/screens/incoming_booking_request_dialog.dart';
import '../bookings/models/booking_model.dart';
import '../../services/sound_service.dart';
import '../../services/booking_service.dart';

import '../notifications/screens/notifications_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const Color _teal = Color(0xFF18C7BD);
  static const Color _deepTeal = Color(0xFF009F98);
  static const Color _navy = Color(0xFF08234C);
  static const Color _mint = Color(0xFFE8FAF7);
  static const Color _page = Color(0xFFF9FCFC);

  int _currentIndex = 0;
  StreamSubscription? _notificationSubscription;
  final Set<String> _processedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
      _startNotificationListener();
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    SoundService.instance.stopSound();
    super.dispose();
  }

  void _startNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) continue;

              final id = change.doc.id;
              if (_processedNotificationIds.contains(id)) continue;
              _processedNotificationIds.add(id);

              _handleIncomingNotification(id, data);
            }
          }
        });
  }

  Future<void> _handleIncomingNotification(
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'];
    final bookingId = data['bookingId'];

    if (bookingId == null) return;

    final bookingDoc = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!bookingDoc.exists) return;
    final booking = BookingModel.fromDocument(bookingDoc);

    if (type == 'booking_request') {
      SoundService.instance.playNotificationSound();
      _showIncomingRequestDialog(booking);
    } else if (type == 'booking_accepted') {
      SoundService.instance.stopSound();
      _showRideConfirmedDialog(booking);
    } else if (type == 'booking_cancelled') {
      SoundService.instance.stopSound();
      _showCancellationDialog(booking);
    }

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  void _showCancellationDialog(BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              'Ride Cancelled',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '${booking.passengerName} has cancelled the ride from ${booking.pickup} to ${booking.destination}.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: _teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIncomingRequestDialog(BookingModel booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        onPopInvokedWithResult: (_, _) async {
          SoundService.instance.stopSound();
        },
        child: IncomingBookingRequestDialog(
          booking: booking,
          onAccept: () async {
            Navigator.pop(context);
            SoundService.instance.stopSound();
            await BookingService().acceptBooking(booking);
          },
          onReject: () async {
            Navigator.pop(context);
            SoundService.instance.stopSound();
            await BookingService().rejectBooking(booking);
          },
        ),
      ),
    );
  }

  void _showRideConfirmedDialog(BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => RideConfirmedDialog(
        booking: booking,
        onViewBooking: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailsScreen(bookingId: booking.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      ref.read(userLocationProvider.notifier).state = pos;
      ref.read(locationServiceProvider).updateCurrentPosition(pos);
    } catch (_) {}
  }

  void _onTabTapped(int index) {
    if (index == 0 || index == _currentIndex) {
      return;
    }

    setState(() => _currentIndex = index);

    switch (index) {
      case 1:
        _openScreen(const FindRideScreen());
        break;
      case 2:
        _openScreen(const MyBookingsScreen());
        break;
      case 3:
        _openScreen(const ProfileScreen());
        break;
    }
  }

  void _openScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      if (!mounted) return;
      setState(() => _currentIndex = 0);
    });
  }

  String _firstName(User? user) {
    final String name = (user?.displayName ?? '').trim();
    if (name.isEmpty) return 'Rider';
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String fullName = (user?.displayName ?? 'AGo User').trim();

    return Scaffold(
      backgroundColor: _page,
      drawer: _buildDrawer(
        user: user,
        fullName: fullName.isEmpty ? 'AGo User' : fullName,
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              _buildHero(_firstName(user)),
              const SizedBox(height: 34),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildPromotionalCards(),
                    const SizedBox(height: 25),
                    Text(
                      'Manage Your Journey',
                      style: GoogleFonts.poppins(
                        color: _navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildJourneyCard(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xDFE5F8F8),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                return IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 22,
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF08234C),
                    size: 30,
                  ),
                );
              },
            ),

            const SizedBox(width: 4),

            // Logo
            Image.asset(
              'assets/images/app_logo.png',
              width: 70,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),

            const SizedBox(width: 8),

            // Tagline (Moved Down)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(0, 7), // ↓ Move down by 5 pixels
                  child: Image.asset(
                    'assets/images/after_logo.png',
                    width: double.infinity,
                    height: 35,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
              ),
            ),

            // Notification Bell with Badge (Extreme Right)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where(
                    'receiverId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final int unreadCount = snapshot.data?.docs.length ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => _openScreen(const NotificationsScreen()),
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF08234C),
                        size: 28,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(String firstName) {
    return SizedBox(
      height: 245,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: 38,
            child: Image.asset(
              'assets/images/home_hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: 26,
            top: 64,
            right: MediaQuery.sizeOf(context).width * 0.43,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $firstName!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Where are you\nheading today?',
                  style: GoogleFonts.poppins(
                    color: _navy.withValues(alpha: 0.68),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 18, right: 18, bottom: 0, child: _buildSearchBar()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openScreen(const FindRideScreen()),
        borderRadius: BorderRadius.circular(23),
        child: Ink(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFE8F0F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: _navy, size: 31),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Enter pickup or destination',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6F747C),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF23DDCE), Color(0xFF0EBDB7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withValues(alpha: 0.26),
                      blurRadius: 9,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            title: 'Find Ride',
            icon: Icons.location_searching_rounded,
            onTap: () => _openScreen(const FindRideScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionCard(
            title: 'Offer Ride',
            icon: Icons.person_add_alt_1_rounded,
            smallIcon: Icons.directions_car_filled_rounded,
            onTap: () => _openScreen(const OfferRideScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionCard(
            title: 'My Bookings',
            icon: Icons.calendar_month_rounded,
            smallIcon: Icons.check_rounded,
            onTap: () => _openScreen(const MyBookingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    IconData? smallIcon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          height: 146,
          padding: const EdgeInsets.fromLTRB(5, 19, 5, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFF0F3F3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 13,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F8F5),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: const Color(0xFF064D66), size: 38),
                    if (smallIcon != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4F8F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            smallIcon,
                            size: 16,
                            color: const Color(0xFF064D66),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionalCards() {
    return Row(
      children: [
        Expanded(child: _buildZeroFeeCard()),
        const SizedBox(width: 9),
        Expanded(child: _buildRideTogetherCard()),
      ],
    );
  }

  Widget _promoShell({required String asset, required Widget child}) {
    return Container(
      height: 124,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFDDF2EF)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (c, e, s) => const SizedBox(),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _buildZeroFeeCard() {
    return _promoShell(
      asset: 'assets/images/zero_fees.png',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 13, 5, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: _deepTeal, size: 25),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Zero\nPlatform Fees',
                    style: GoogleFonts.poppins(
                      color: _navy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.16,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _deepTeal,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                '100% Fee-Free',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideTogetherCard() {
    return _promoShell(
      asset: 'assets/images/ride_together.png',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 14, 5, 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 86,
            child: Text(
              'Travel Smarter.\nRide Together.',
              style: GoogleFonts.poppins(
                color: _navy,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJourneyCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFF3F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildJourneyTile(
            title: 'Booking Requests',
            subtitle: 'Accept or reject passenger requests',
            icon: Icons.mark_email_unread_outlined,
            onTap: () => _openScreen(DriverBookingRequestsScreen()),
          ),
          _journeyDivider(),
          _buildJourneyTile(
            title: 'My Offered Rides',
            subtitle: 'Manage your published rides',
            icon: Icons.directions_car_filled_rounded,
            onTap: () => _openScreen(const MyOfferedRidesScreen()),
          ),
          _journeyDivider(),
          _buildJourneyTile(
            title: 'Driver Dashboard',
            subtitle: 'View trip and request statistics',
            icon: Icons.bar_chart_rounded,
            onTap: () => _openScreen(const DriverDashboardScreen()),
          ),
          _journeyDivider(),
          _buildJourneyTile(
            title: 'Ride History',
            subtitle: 'View completed and cancelled rides',
            icon: Icons.history_rounded,
            onTap: () => _openScreen(const RideHistoryScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F8F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _deepTeal, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _navy,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF7A8088),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _navy, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _journeyDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 69,
      endIndent: 14,
      color: Color(0xFFEFF2F2),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 17,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(index: 0, icon: Icons.home_rounded, label: 'Home'),
              _buildNavItem(
                index: 1,
                icon: Icons.explore_outlined,
                label: 'Explore',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.calendar_month_outlined,
                label: 'Bookings',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _currentIndex == index;
    final Color color = selected ? _teal : const Color(0xFF1E2A42);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer({required User? user, required String fullName}) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(user: user, fullName: fullName),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(21, 18, 21, 8),
                children: [
                  _drawerSectionTitle('RIDE'),
                  _drawerItem(
                    icon: Icons.location_searching_rounded,
                    title: 'Find Ride',
                    onTap: () => _openScreen(const FindRideScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Offer Ride',
                    onTap: () => _openScreen(const OfferRideScreen()),
                  ),
                  _drawerDivider(),
                  _drawerSectionTitle('ACTIVITY'),
                  _drawerItem(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Booking Requests',
                    onTap: () => _openScreen(DriverBookingRequestsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.calendar_month_outlined,
                    title: 'My Bookings',
                    onTap: () => _openScreen(const MyBookingsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.directions_car_filled_rounded,
                    title: 'My Offered Rides',
                    onTap: () => _openScreen(const MyOfferedRidesScreen()),
                  ),
                  _drawerDivider(),
                  _drawerSectionTitle('MORE'),
                  _drawerItem(
                    icon: Icons.grid_view_rounded,
                    title: 'Driver Dashboard',
                    onTap: () => _openScreen(const DriverDashboardScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.history_rounded,
                    title: 'Ride History',
                    onTap: () => _openScreen(const RideHistoryScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () => _openScreen(const NotificationsScreen()),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Version 1.0',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, size: 21),
                  label: Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5A5F),
                    side: const BorderSide(color: Color(0xFFFF8C8F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader({required User? user, required String fullName}) {
    if (user == null) {
      return _drawerHeaderContent(
        name: fullName,
        email: '',
        photoUrl: '',
        avatarIndex: null,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic> data = snapshot.data?.data() ?? {};
        final String name = (data['name'] ?? user.displayName ?? fullName)
            .toString();
        final String email = (data['email'] ?? user.email ?? '').toString();
        final String photoUrl = (data['photoUrl'] ?? user.photoURL ?? '')
            .toString();
        final dynamic storedAvatar = data['avatarIndex'];
        final int? avatarIndex = storedAvatar is int
            ? storedAvatar
            : int.tryParse(storedAvatar?.toString() ?? '');

        return _drawerHeaderContent(
          name: name,
          email: email,
          photoUrl: photoUrl,
          avatarIndex: avatarIndex,
        );
      },
    );
  }

  Widget _drawerHeaderContent({
    required String name,
    required String email,
    required String photoUrl,
    required int? avatarIndex,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _openScreen(const ProfileScreen());
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _mint,
          image: const DecorationImage(
            image: AssetImage('assets/images/profile_hero.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(36),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(25, 34, 20, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(36),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_teal, Color(0xFF22DFCF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _teal.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: AppAvatar(
                        avatarIndex: avatarIndex,
                        photoUrl: photoUrl,
                        size: 78,
                        borderColor: Colors.transparent,
                        borderWidth: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _navy.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }


  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 5),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: _deepTeal,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 3),
      minTileHeight: 61,
      leading: Container(
        width: 47,
        height: 47,
        decoration: BoxDecoration(
          color: const Color(0xFFE4F8F5),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: const Color(0xFF07516A), size: 25),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: _navy,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _navy, size: 23),
    );
  }

  Widget _drawerDivider() {
    return const Divider(height: 26, color: Color(0xFFE5EEEE));
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
    }
  }
}
