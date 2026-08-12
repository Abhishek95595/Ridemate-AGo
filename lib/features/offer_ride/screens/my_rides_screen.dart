import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ride_model.dart';
import 'create_ride_screen.dart';
import 'edit_ride_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isCancelling = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _getMyRides() {
    final String? userId = _auth.currentUser?.uid;

    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> _openCreateRideScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRideScreen()),
    );
  }

  Future<void> _openEditRideScreen(RideModel ride) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditRideScreen(ride: ride)),
    );
  }

  Future<void> _cancelRide({
    required String rideId,
    required RideModel ride,
  }) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Cancel Ride'),
            ],
          ),
          content: Text(
            'Are you sure you want to cancel the ride from '
            '${ride.pickup} to ${ride.destination}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) {
      return;
    }

    try {
      setState(() {
        _isCancelling = true;
      });

      await _firestore.collection('rides').doc(rideId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride cancelled successfully'),
          backgroundColor: Colors.red,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to cancel ride'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  bool _isCancelled(RideModel ride) {
    return ride.status.toLowerCase() == 'cancelled';
  }

  String _formatCreatedDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Offered Rides',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRideScreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Offer Ride'),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _getMyRides(),
            builder: (context, snapshot) {
              if (_auth.currentUser == null) {
                return _buildMessageState(
                  icon: Icons.login_rounded,
                  title: 'Login required',
                  message: 'Please login to see your offered rides.',
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildMessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load rides',
                  message: snapshot.error.toString(),
                );
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              documents = snapshot.data?.docs ?? [];

              if (documents.isEmpty) {
                return _buildEmptyState();
              }

              final List<RideModel> rides = documents.map((document) {
                return RideModel.fromMap(document.data(), document.id);
              }).toList();

              rides.sort((firstRide, secondRide) {
                final DateTime firstDate =
                    firstRide.createdAt ?? DateTime(2000);
                final DateTime secondDate =
                    secondRide.createdAt ?? DateTime(2000);

                return secondDate.compareTo(firstDate);
              });

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                itemCount: rides.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 16);
                },
                itemBuilder: (context, index) {
                  final RideModel ride = rides[index];

                  return _buildRideCard(ride);
                },
              );
            },
          ),
          if (_isCancelling)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cancelling ride...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRideCard(RideModel ride) {
    final bool isCancelled = _isCancelled(ride);
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCancelled
              ? Colors.red.withValues(alpha: 0.35)
              : Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.withValues(alpha: 0.10)
                        : primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: isCancelled ? Colors.red : primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ride.pickup} → ${ride.destination}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _buildStatusBadge(isCancelled),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLocationRow(
              icon: Icons.radio_button_checked_rounded,
              iconColor: Colors.green,
              title: 'Pickup',
              location: ride.pickup,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: 18,
                color: Theme.of(context).dividerColor,
              ),
            ),
            _buildLocationRow(
              icon: Icons.location_on_rounded,
              iconColor: Colors.red,
              title: 'Destination',
              location: ride.destination,
            ),
            const SizedBox(height: 18),
            Divider(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInformationBox(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date',
                    value: ride.date.isEmpty
                        ? _formatCreatedDate(ride.createdAt)
                        : ride.date,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInformationBox(
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: ride.time.isEmpty ? 'Not available' : ride.time,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildInformationBox(
                    icon: Icons.directions_car_filled_rounded,
                    label: 'Vehicle',
                    value: ride.vehicle.isEmpty
                        ? 'Not available'
                        : ride.vehicle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInformationBox(
                    icon: Icons.event_seat_rounded,
                    label: 'Available',
                    value: '${ride.seats} seats',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.currency_rupee_rounded,
                    color: Colors.green,
                    size: 21,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${ride.price} per seat',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (ride.description.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Ride description',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.60),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                ride.description,
                style: TextStyle(
                  height: 1.4,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
            if (ride.ac || ride.smoking) ...[
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (ride.ac)
                    _buildPreferenceChip(
                      icon: Icons.ac_unit_rounded,
                      label: 'AC available',
                    ),
                  if (ride.smoking)
                    _buildPreferenceChip(
                      icon: Icons.smoking_rooms_rounded,
                      label: 'Smoking allowed',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: isCancelled
                          ? null
                          : () {
                              _openEditRideScreen(ride);
                            },
                      icon: const Icon(Icons.edit_rounded, size: 19),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: isCancelled
                          ? null
                          : () {
                              _cancelRide(rideId: ride.id, ride: ride);
                            },
                      icon: Icon(
                        isCancelled
                            ? Icons.block_rounded
                            : Icons.cancel_outlined,
                        size: 19,
                      ),
                      label: Text(isCancelled ? 'Cancelled' : 'Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCancelled
                            ? Colors.grey
                            : Colors.red.withValues(alpha: 0.10),
                        foregroundColor: isCancelled
                            ? Colors.white
                            : Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String location,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location.isEmpty ? 'Not available' : location,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInformationBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isCancelled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isCancelled
            ? Colors.red.withValues(alpha: 0.10)
            : Colors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCancelled ? 'Cancelled' : 'Active',
        style: TextStyle(
          color: isCancelled ? Colors.red : Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPreferenceChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: 55,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No offered rides',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Create your first ride and start sharing your journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateRideScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Offer a Ride'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
