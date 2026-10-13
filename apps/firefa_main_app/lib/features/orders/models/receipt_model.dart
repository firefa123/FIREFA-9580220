class ReceiptModel {
  final String transactionId;
  final String paymentId;
  final DateTime issuedAt;
  final double totalAmount;
  final String paymentMethod;

  const ReceiptModel({
    required this.transactionId,
    required this.paymentId,
    required this.issuedAt,
    required this.totalAmount,
    required this.paymentMethod,
  });
}
