import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RateDriverBottomSheet extends StatefulWidget {
  final String rideId;
  final String bookingId;
  final String driverId;
  final String driverName;

  const RateDriverBottomSheet({
    super.key,
    required this.rideId,
    required this.bookingId,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<RateDriverBottomSheet> createState() => _RateDriverBottomSheetState();
}

class _RateDriverBottomSheetState extends State<RateDriverBottomSheet> {
  int _selectedRating = 0;
  bool _isSubmitting = false;

  final TextEditingController _reviewController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _submitReview() async {
    if (_selectedRating == 0 || _isSubmitting) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in again before submitting a review.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final DocumentSnapshot<Map<String, dynamic>> passengerSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final Map<String, dynamic> passengerData =
          passengerSnapshot.data() ?? <String, dynamic>{};

      final DocumentReference<Map<String, dynamic>> driverReference = _firestore
          .collection('users')
          .doc(widget.driverId);

      final DocumentReference<Map<String, dynamic>> bookingReference =
          _firestore.collection('bookings').doc(widget.bookingId);

      final DocumentReference<Map<String, dynamic>> reviewReference = _firestore
          .collection('driver_reviews')
          .doc(widget.bookingId);

      final String passengerName =
          passengerData['name']?.toString().trim().isNotEmpty == true
          ? passengerData['name'].toString()
          : user.displayName ?? 'Anonymous';

      final String passengerPhotoUrl =
          passengerData['photoUrl']?.toString() ?? user.photoURL ?? '';

      // Check existing booking / review status
      DocumentSnapshot<Map<String, dynamic>>? bookingSnapshot;
      try {
        bookingSnapshot = await bookingReference.get();
      } catch (e) {
        debugPrint('Note: could not read booking: $e');
      }

      if (bookingSnapshot != null && bookingSnapshot.exists) {
        final Map<String, dynamic> bookingData =
            bookingSnapshot.data() ?? <String, dynamic>{};

        final String bookingPassengerId =
            bookingData['passengerId']?.toString() ?? '';

        if (bookingPassengerId.isNotEmpty && bookingPassengerId != user.uid) {
          throw Exception('You are not allowed to rate this booking.');
        }

        if (bookingData['isRated'] == true ||
            bookingData['reviewSubmitted'] == true) {
          throw Exception('You have already submitted a rating.');
        }
      }

      final Map<String, dynamic> reviewData = <String, dynamic>{
        'rideId': widget.rideId,
        'bookingId': widget.bookingId,
        'driverId': widget.driverId,
        'passengerId': user.uid,
        'passengerName': passengerName,
        'passengerPhotoUrl': passengerPhotoUrl,
        'passengerAvatarIndex': passengerData['avatarIndex'],
        'rating': _selectedRating,
        'review': _reviewController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Save review to driver_reviews
      try {
        await reviewReference.set(reviewData, SetOptions(merge: true));
      } catch (e) {
        debugPrint('driver_reviews set: $e');
      }

      // 2. Add to ratings collection
      try {
        await _firestore.collection('ratings').add(<String, dynamic>{
          'bookingId': widget.bookingId,
          'fromUserId': user.uid,
          'toUserId': widget.driverId,
          'rating': _selectedRating,
          'review': _reviewController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('ratings add: $e');
      }

      // 3. Mark booking as rated
      try {
        await bookingReference.update(<String, dynamic>{
          'isRated': true,
          'reviewSubmitted': true,
          'driverRating': _selectedRating,
          'ratedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('bookingReference update: $e');
      }

      // 4. Try updating driver user document stats (silently catch if security rules forbid passenger editing driver's profile)
      try {
        final DocumentSnapshot<Map<String, dynamic>> driverSnapshot =
            await driverReference.get();
        double currentAverageRating = 0;
        int currentTotalRatings = 0;

        if (driverSnapshot.exists) {
          final Map<String, dynamic> driverData =
              driverSnapshot.data() ?? <String, dynamic>{};
          currentAverageRating =
              (driverData['averageRating'] as num?)?.toDouble() ?? 0;
          currentTotalRatings =
              (driverData['totalRatings'] as num?)?.toInt() ?? 0;
        }

        final int newTotalRatings = currentTotalRatings + 1;
        final double newAverageRating =
            ((currentAverageRating * currentTotalRatings) + _selectedRating) /
            newTotalRatings;

        await driverReference.set(<String, dynamic>{
          'averageRating': newAverageRating,
          'totalRatings': newTotalRatings,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Driver user doc update skipped: $e');
      }

      await _updateActiveRideRating();

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your review!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint('Firebase review error code: ${error.code}');

      debugPrint('Firebase review error message: ${error.message}');

      if (!mounted) {
        return;
      }

      String message = error.message ?? 'Failed to submit review.';

      if (error.code == 'permission-denied') {
        message = 'Permission denied. Check your Firestore rules.';
      }

      _showMessage(message, isError: true);
    } catch (error) {
      debugPrint('Review submission error: $error');

      if (!mounted) {
        return;
      }

      String message = error.toString();

      if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }

      _showMessage(message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateActiveRideRating() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> driverSnapshot =
          await _firestore.collection('users').doc(widget.driverId).get();

      if (!driverSnapshot.exists) {
        return;
      }

      final Map<String, dynamic> driverData =
          driverSnapshot.data() ?? <String, dynamic>{};

      final double averageRating =
          (driverData['averageRating'] as num?)?.toDouble() ?? 0;

      final int totalRatings =
          (driverData['totalRatings'] as num?)?.toInt() ?? 0;

      final QuerySnapshot<Map<String, dynamic>> activeRidesSnapshot =
          await _firestore
              .collection('rides')
              .where('driverId', isEqualTo: widget.driverId)
              .where('status', isEqualTo: 'active')
              .get();

      if (activeRidesSnapshot.docs.isEmpty) {
        return;
      }

      final WriteBatch batch = _firestore.batch();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> rideDocument
          in activeRidesSnapshot.docs) {
        batch.update(rideDocument.reference, <String, dynamic>{
          'driverRating': averageRating,
          'driverTotalReviews': totalRatings,
        });
      }

      await batch.commit();
    } catch (error) {
      debugPrint('Could not update active ride rating: $error');
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Rate your journey with',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 4),

              Text(
                widget.driverName,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF08234C),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(5, (int index) {
                  final int value = index + 1;

                  return IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _selectedRating = value;
                            });
                          },
                    icon: Icon(
                      value <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _reviewController,
                maxLines: 3,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Add a comment (optional)',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF14D8C4),
                      width: 1.5,
                    ),
                  ),
                ),
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 32),

              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      child: Text(
                        'SKIP',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _selectedRating == 0 || _isSubmitting
                            ? null
                            : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14D8C4),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF8ADFD5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'SUBMIT',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
