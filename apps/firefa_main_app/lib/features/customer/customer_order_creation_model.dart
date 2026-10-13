class CustomerOrderCreationModel {
  final String orderId;
  final double subtotal;
  final String status;

  const CustomerOrderCreationModel({
    required this.orderId,
    required this.subtotal,
    required this.status,
  });
}
