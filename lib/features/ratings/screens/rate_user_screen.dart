import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RateUserScreen extends StatefulWidget {
  final String bookingId;
  final String toUserId;
  final String toUserName;
  final num? fare;

  const RateUserScreen({
    super.key,
    required this.bookingId,
    required this.toUserId,
    required this.toUserName,
    this.fare,
  });

  @override
  State<RateUserScreen> createState() => _RateUserScreenState();
}

class _RateUserScreenState extends State<RateUserScreen> {
  int rating = 0;
  bool isSubmitting = false;

  Future<void> submit() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || rating == 0 || isSubmitting) {
      if (rating == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a star rating.')),
        );
      }
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('ratings').add({
        'bookingId': widget.bookingId,
        'fromUserId': user.uid,
        'toUserId': widget.toUserId,
        'rating': rating,
        'review': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save rating. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    const Color teal = Color(0xFF10B7AA);
    const Color navy = Color(0xFF071B3A);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF07172C) : const Color(0xFFB9C0CC),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 19,
              top: 13,
              child: Material(
                color: dark ? const Color(0xFF13283B) : Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(30),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: dark ? Colors.white : navy,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(25, 80, 25, 30),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.fromLTRB(28, 31, 28, 27),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF13283B) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 114,
                            height: 114,
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF0D3542)
                                  : const Color(0xFFE3F8F4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFBEEFE8),
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_car_filled_rounded,
                              color: teal,
                              size: 65,
                            ),
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 39,
                              height: 39,
                              decoration: const BoxDecoration(
                                color: Color(0xFF17C7B6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Thanks for riding! 🏁',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: dark ? Colors.white : navy,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Your journey with ${widget.toUserName}\nis complete.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: dark
                              ? Colors.white70
                              : const Color(0xFF65707D),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      if (widget.fare != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF0D3542)
                                : const Color(0xFFEEFAF8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFCFEDE8)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'PLEASE PAY',
                                style: GoogleFonts.poppins(
                                  color: dark
                                      ? Colors.white60
                                      : const Color(0xFF7B858E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                '₹${widget.fare}',
                                style: GoogleFonts.poppins(
                                  color: teal,
                                  fontSize: 43,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Divider(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE4ECEB),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Rate your experience:',
                        style: GoogleFonts.poppins(
                          color: dark ? Colors.white : navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final int value = index + 1;
                          return IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: isSubmitting
                                ? null
                                : () => setState(() => rating = value),
                            icon: Icon(
                              value <= rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: teal,
                              size: 39,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 17),
                      SizedBox(
                        width: double.infinity,
                        height: 57,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : submit,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(
                                  Icons.account_balance_wallet_rounded,
                                ),
                          label: Text(
                            isSubmitting
                                ? 'SAVING...'
                                : widget.fare == null
                                ? 'SUBMIT RATING'
                                : 'PAY & RATE DRIVER',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: teal,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF78CFC7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
