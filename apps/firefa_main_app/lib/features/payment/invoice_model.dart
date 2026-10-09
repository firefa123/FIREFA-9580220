class InvoiceModel {
  final String invoiceId;
  final String transactionId;
  final double amount;

  const InvoiceModel({
    required this.invoiceId,
    required this.transactionId,
    required this.amount,
  });
}
