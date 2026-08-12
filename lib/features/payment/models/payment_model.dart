enum PaymentStatus { pending, success, failed, cancelled }

class PaymentModel {
  final String bookingId;
  final String transactionId;
  final String transactionRef;
  final double amount;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? upiApp;

  PaymentModel({
    required this.bookingId,
    required this.transactionId,
    required this.transactionRef,
    required this.amount,
    required this.status,
    required this.timestamp,
    this.upiApp,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'transactionId': transactionId,
      'transactionRef': transactionRef,
      'amount': amount,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'upiApp': upiApp,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      bookingId: map['bookingId'],
      transactionId: map['transactionId'],
      transactionRef: map['transactionRef'],
      amount: map['amount'],
      status: PaymentStatus.values.byName(map['status']),
      timestamp: DateTime.parse(map['timestamp']),
      upiApp: map['upiApp'],
    );
  }
}
