import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../map/widgets/location_search_widget.dart';
import 'shimmer_ride_card.dart';
import '../../core/widgets/app_avatar.dart';
import '../offer_ride/models/ride_model.dart';
import '../../core/widgets/driver_rating_widget.dart';
import '../profile/models/user_model.dart';
import '../profile/screen/edit_profile_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ago/features/map/providers/location_provider.dart';

part 'widgets/find_ride_card.dart';

class FindRideScreen extends ConsumerStatefulWidget {
  const FindRideScreen({super.key});

  @override
  ConsumerState<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends ConsumerState<FindRideScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  String pickupSearch = '';
  String destinationSearch = '';
  final Set<String> _bookingRideIds = {};
  final Map<String, int> _selectedSeats = {};
  final Map<String, int> _userBookedSeatsMap = {};
  StreamSubscription? _userBookingsSubscription;

  bool _isManuallyRefreshing = false;
  String? _locationError;
  Timer? _refreshTimer;

  late AnimationController _animationController;
  late Animation<Offset> _searchSlideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _searchSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();

    _listenToUserBookings();

    // Rebuild every minute so rides automatically disappear when they
    // enter the 30-minute cutoff window, even if Firestore has no changes.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _listenToUserBookings() {
    final user = _auth.currentUser;
    if (user == null) return;

    _userBookingsSubscription = _firestore
        .collection('bookings')
        .where('passengerId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'accepted'])
        .snapshots()
        .listen((snapshot) {
          final Map<String, int> newMap = {};
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final rideId = data['rideId']?.toString() ?? '';
            final seats =
                int.tryParse(data['seatsBooked']?.toString() ?? '0') ?? 0;
            newMap[rideId] = (newMap[rideId] ?? 0) + seats;
          }
          if (mounted) {
            setState(() {
              _userBookedSeatsMap.clear();
              _userBookedSeatsMap.addAll(newMap);
            });
          }
        });
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isManuallyRefreshing = true;
      _locationError = null;
    });
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      ref.read(userLocationProvider.notifier).state = pos;
    } catch (e) {
      if (mounted) setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _isManuallyRefreshing = false);
    }
  }

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    _refreshTimer?.cancel();
    _userBookingsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getRidesStream(
    Position currentPosition,
  ) {
    final bool isSearchingManually =
        pickupSearch.isNotEmpty || destinationSearch.isNotEmpty;

    if (!isSearchingManually) {
      // 1. NEARBY SEARCH (When search bar is empty)
      final GeoFirePoint center = GeoFirePoint(
        GeoPoint(currentPosition.latitude, currentPosition.longitude),
      );

      final collectionRef = _firestore
          .collection('rides')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );

      return GeoCollectionReference<Map<String, dynamic>>(
        collectionRef,
      ).subscribeWithin(
        center: center,
        radiusInKm: 5.0,
        field: 'pickupPosition',
        geopointFrom: (data) {
          final position = data['pickupPosition'];
          if (position is Map<String, dynamic>) {
            return position['geopoint'] as GeoPoint;
          } else if (position is GeoPoint) {
            return position;
          }
          return data['pickupGeoPoint'] as GeoPoint;
        },
        strictMode: false,
      );
    } else {
      // 2. GLOBAL SEARCH (When search bar has text)
      // Note: Firestore doesn't support complex text search well,
      // so we fetch active rides and filter in memory as per existing logic in _isValidRide.
      return _firestore
          .collection('rides')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snapshot) => snapshot.docs);
    }
  }

  void searchRides() {
    FocusScope.of(context).unfocus();
    setState(() {
      pickupSearch = pickupController.text.trim().toLowerCase();
      destinationSearch = destinationController.text.trim().toLowerCase();
    });
  }

  bool _isValidRide(RideModel ride) {
    // 1. Basic Status Check
    if (ride.status != 'active') {
      debugPrint('FILTER ${ride.id}: status=${ride.status}');
      return false;
    }

    if (ride.availableSeats <= 0) {
      debugPrint('FILTER ${ride.id}: no seats (${ride.availableSeats})');
      return false;
    }

    // 2. 15-minute cutoff check (Updated from 30)
    if (ride.departureTimestamp != null) {
      final now = DateTime.now();
      final cutoff = ride.departureTimestamp!.subtract(
        const Duration(minutes: 15),
      );
      if (now.isAfter(cutoff)) {
        debugPrint(
          'FILTER ${ride.id}: departure cutoff. '
          'departure=${ride.departureTimestamp}, now=$now',
        );
        return false;
      }
    }

    // 3. Own Ride Check (Driver shouldn't see their own offered rides)
    if (ride.driverId == _auth.currentUser?.uid) {
      debugPrint('FILTER ${ride.id}: own ride');
      return false;
    }

    // 4. Search Text Filters
    final String pickup = ride.pickup.toLowerCase();
    final String destination = ride.destination.toLowerCase();

    if (pickupSearch.isNotEmpty && !pickup.contains(pickupSearch)) {
      debugPrint(
        'FILTER ${ride.id}: pickup mismatch '
        'ride="$pickup" search="$pickupSearch"',
      );
      return false;
    }

    if (destinationSearch.isNotEmpty &&
        !destination.contains(destinationSearch)) {
      debugPrint(
        'FILTER ${ride.id}: destination mismatch '
        'ride="$destination" search="$destinationSearch"',
      );
      return false;
    }

    return true;
  }

  Future<void> bookRide({
    required String rideId,
    required RideModel ride,
    required int requestedSeats,
  }) async {
    if (_bookingRideIds.contains(rideId)) return;

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showMessage('Please login before booking.', isError: true);
      return;
    }

    // Check if profile is complete (Photo + Phone)
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    if (userDoc.exists) {
      final userModel = UserModel.fromMap(userDoc.data()!, userDoc.id);
      if (!userModel.hasBasicProfile) {
        if (!mounted) return;
        _showProfileIncompleteDialog(userDoc.data()!);
        return;
      }
    }

    if (!mounted) return;

    if (ride.driverId == currentUser.uid) {
      _showMessage('You cannot book your own offered ride.', isError: true);
      return;
    }

    // Check if already booked
    final int alreadyBooked = _userBookedSeatsMap[rideId] ?? 0;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          alreadyBooked > 0 ? "Additional Seat Booking" : "Confirm Booking",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alreadyBooked > 0) ...[
              Text(
                "You have already booked $alreadyBooked seat(s) for this ride.",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              "Do you want to book a ride with the following details?",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            _buildDialogRouteInfo(ride),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.event_seat_rounded,
                  size: 18,
                  color: Color(0xFF14D8C4),
                ),
                const SizedBox(width: 8),
                Text(
                  "Seats: $requestedSeats",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "CANCEL",
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14D8C4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              alreadyBooked > 0 ? "BOOK MORE" : "CONFIRM",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _bookingRideIds.add(rideId));

    try {
      final String passengerName =
          currentUser.displayName ??
          currentUser.email?.split('@').first ??
          'Passenger';
      final DocumentReference bookingRef = _firestore
          .collection('bookings')
          .doc();
      final DocumentReference notificationRef = _firestore
          .collection('notifications')
          .doc();

      await _firestore.runTransaction((transaction) async {
        final rideRef = _firestore.collection('rides').doc(rideId);
        final rideSnap = await transaction.get(rideRef);

        if (!rideSnap.exists) throw Exception('Ride no longer exists.');
        final data = rideSnap.data()!;
        final int seats =
            int.tryParse(
              data['availableSeats']?.toString() ??
                  data['seats']?.toString() ??
                  '0',
            ) ??
            0;

        if (seats < requestedSeats) {
          throw Exception('Only $seats seats available.');
        }

        final double basePrice =
            double.tryParse(data['price']?.toString() ?? '0') ?? 0;
        final double totalPrice = basePrice * requestedSeats;

        transaction.set(bookingRef, {
          'id': bookingRef.id,
          'rideId': rideId,
          'passengerId': currentUser.uid,
          'passengerName': passengerName,
          'driverId': ride.driverId,
          'pickup': ride.pickup,
          'destination': ride.destination,
          'status': 'pending',
          'price': basePrice,
          'totalPrice': totalPrice,
          'seatsBooked': requestedSeats,
          'date': ride.date,
          'time': ride.time,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(notificationRef, {
          'id': notificationRef.id,
          'receiverId': ride.driverId,
          'senderId': currentUser.uid,
          'type': 'booking_request',
          'title': 'New Booking Request',
          'message': '$passengerName requested $requestedSeats seats.',
          'bookingId': bookingRef.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Decrement available seats immediately on request to reserve them.
        // If rejected or cancelled, they will be restored.
        transaction.update(rideRef, {'availableSeats': seats - requestedSeats});
      });

      _showMessage('Booking request sent successfully!');
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _bookingRideIds.remove(rideId));
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF087E94),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildDialogRouteInfo(RideModel ride) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.radio_button_checked,
              size: 14,
              color: Color(0xFF14D8C4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ride.pickup,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(left: 6),
          height: 15,
          width: 2,
          color: Colors.grey[300],
        ),
        Row(
          children: [
            const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ride.destination,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111318)
          : const Color(0xFFF9FCFC),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: Column(
              children: [
                SlideTransition(
                  position: _searchSlideAnimation,
                  child: _buildSearchSection(isDark),
                ),
                Expanded(child: _buildRidesList(isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesList(bool isDark) {
    final Position? currentPosition = ref.watch(userLocationProvider);

    if (currentPosition == null) {
      debugPrint('FindRide: Current position is NULL');
      if (_isManuallyRefreshing) {
        return ListView.builder(
          itemCount: 3,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemBuilder: (context, index) => const ShimmerRideCard(),
        );
      }
      if (_locationError != null) {
        return _buildErrorState(isDark, _locationError!);
      }
      return _buildNoLocationState(isDark);
    }

    debugPrint(
      'FindRide: Searching near ${currentPosition.latitude}, ${currentPosition.longitude}',
    );

    return StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      stream: getRidesStream(currentPosition),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            itemCount: 3,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemBuilder: (context, index) => const ShimmerRideCard(),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            isDark,
            'Unable to load nearby rides. Please try again.',
          );
        }

        final docs = snapshot.data ?? [];
        debugPrint('Nearby Firestore documents: ${docs.length}');

        final List<RideModel> rides = docs
            .map((doc) {
              final ride = RideModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
              if (!_isValidRide(ride)) {
                debugPrint(
                  'Ride ${doc.id} filtered out. Status: ${ride.status}, Seats: ${ride.availableSeats}, Driver: ${ride.driverId}, User: ${_auth.currentUser?.uid}',
                );
              }
              return ride;
            })
            .where(_isValidRide)
            .toList();

        debugPrint('Valid rides after filters: ${rides.length}');

        // Sorting:
        // 1. Nearest pickup
        // 2. Earliest departure
        // 3. Highest driver rating
        rides.sort((a, b) {
          final double distA = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            a.pickupLat ?? 0,
            a.pickupLng ?? 0,
          );

          final double distB = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            b.pickupLat ?? 0,
            b.pickupLng ?? 0,
          );

          final int distanceComparison = distA.compareTo(distB);
          if (distanceComparison != 0) {
            return distanceComparison;
          }

          final DateTime departureA = a.departureTimestamp!;
          final DateTime departureB = b.departureTimestamp!;
          final int departureComparison = departureA.compareTo(departureB);

          if (departureComparison != 0) {
            return departureComparison;
          }

          return b.driverRating.compareTo(a.driverRating);
        });

        if (rides.isEmpty) return _buildEmptyState(isDark);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
          itemCount: rides.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final ride = rides[index];
            final id = ride.id;

            final int selectedSeats = _selectedSeats[id] ?? 1;

            final double distance = Geolocator.distanceBetween(
              currentPosition.latitude,
              currentPosition.longitude,
              ride.pickupLat ?? 0,
              ride.pickupLng ?? 0,
            );

            final int alreadyBooked = _userBookedSeatsMap[id] ?? 0;

            return _FindRideCard(
              ride: ride,
              distance: distance,
              isDark: isDark,
              isBooking: _bookingRideIds.contains(id),
              selectedSeats: selectedSeats,
              alreadyBooked: alreadyBooked,
              onSeatsChanged: (val) {
                setState(() {
                  _selectedSeats[id] = val;
                });
              },
              onBook: () => bookRide(
                rideId: id,
                ride: ride,
                requestedSeats: selectedSeats,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoLocationState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_disabled_rounded,
              size: 80,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Location Access Required',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To suggest rides within 5 km, we need to know your current location.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _refreshLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Allow & Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14D8C4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D24) : const Color(0xFFE8FAF7),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : const Color(0xFF08234C),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Text(
            'Find Ride',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF08234C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      child: Column(
        children: [
          LocationSearchWidget(
            label: "Leaving from",
            icon: Icons.radio_button_checked,
            iconColor: const Color(0xFF14D8C4),
            controller: pickupController,
            onSelected: (loc) {
              setState(() {
                pickupController.text = loc.name;
                pickupSearch = loc.name;
              });
            },
          ),
          const SizedBox(height: 12),
          LocationSearchWidget(
            label: "Going to",
            icon: Icons.location_on,
            iconColor: Colors.redAccent,
            controller: destinationController,
            onSelected: (loc) {
              setState(() {
                destinationController.text = loc.name;
                destinationSearch = loc.name;
              });
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF24CFC5), Color(0xFF08AFA9)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14D8C4).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: searchRides,
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                label: Text(
                  'SEARCH RIDES',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 100,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No rides available.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try changing your pickup location or refresh after a few minutes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 160,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _refreshLocation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14D8C4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _refreshLocation,
              child: const Text('Grant Permission / Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileIncompleteDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          "Profile Incomplete",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "To book a ride, you must upload a profile photo and add your phone number.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profileData: data),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14D8C4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "COMPLETE NOW",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
