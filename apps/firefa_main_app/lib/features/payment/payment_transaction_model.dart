class PaymentTransaction {
  final String transactionId;
  final String orderId;
  final double amount;
  final String method;
  final String status;

  const PaymentTransaction({
    required this.transactionId,
    required this.orderId,
    required this.amount,
    required this.method,
    required this.status,
  });
}
