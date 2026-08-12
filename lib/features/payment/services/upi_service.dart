import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UPIService {
  /// Opens a specific UPI app or the system chooser.
  /// Uses specific schemes to bypass generic "Risk Policy" blocks in Paytm/PhonePe.
  Future<void> openUpiPayment({
    required BuildContext context,
    required String driverUid,
    required double amount,
    required String rideId,
    required String bookingId,
  }) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverUid)
          .get();

      if (!driverDoc.exists) throw Exception('Driver profile not found.');

      final data = driverDoc.data() ?? {};
      final String upiId = data['upiId']?.toString().trim() ?? '';
      final String driverName = data['name']?.toString().trim() ?? 'Driver';

      if (upiId.isEmpty) throw Exception('Driver has not added a UPI ID.');

      // Construct standard UPI URI using Uri class for proper encoding.
      // 1. pa: Payee VPA
      // 2. pn: Payee Name
      // 3. am: Amount
      // 4. cu: Currency
      // 5. tn: Transaction Note
      // 6. tr: Transaction Reference (Removed or simplified for P2P)
      final Uri upiUri = Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {
          'pa': upiId,
          'pn': driverName,
          'am': amount.toStringAsFixed(2),
          'cu': 'INR',
          'tn': 'AGo Payment',
          // Note: P2P transfers sometimes fail if 'tr' (Transaction Ref) is too complex or looks like a merchant ID
        },
      );

      // Check if we can launch the URL to avoid "component name is null" issues
      final bool canLaunch = await canLaunchUrl(upiUri);

      if (!canLaunch) {
        throw Exception('No UPI apps found that can handle this payment link.');
      }

      final bool launched = await launchUrl(
        upiUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Failed to open UPI application.');
      }

      // Show confirmation dialog after returning
      if (context.mounted) {
        _showPaymentConfirmationDialog(context, bookingId, upiId);
      }
    } catch (error) {
      if (!context.mounted) return;
      _showErrorWithCopy(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        driverUid,
      );
    }
  }

  void _showPaymentConfirmationDialog(
    BuildContext context,
    String bookingId,
    String upiId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          "Payment Status",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "If your UPI app showed a 'Risk Alert', please use 'Copy UPI ID' and pay manually.",
            ),
            const SizedBox(height: 15),
            const Text(
              "Did you complete the payment?",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: upiId));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("UPI ID Copied for Manual Payment"),
                ),
              );
            },
            child: const Text(
              "COPY UPI ID",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _markAsSubmitted(context, bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14D8C4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("YES, PAID"),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsSubmitted(BuildContext context, String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'paymentStatus': 'submitted_by_passenger',
            'paymentMethod': 'upi_intent',
            'submittedAt': FieldValue.serverTimestamp(),
          });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment Submitted! Driver will verify."),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _showErrorWithCopy(
    BuildContext context,
    String message,
    String driverUid,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(driverUid)
        .get();
    final upi = doc.data()?['upiId'] ?? '';
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error: $message. Copy UPI ID and pay manually."),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
        action: upi.isNotEmpty
            ? SnackBarAction(
                label: "COPY UPI",
                textColor: Colors.white,
                onPressed: () => Clipboard.setData(ClipboardData(text: upi)),
              )
            : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
