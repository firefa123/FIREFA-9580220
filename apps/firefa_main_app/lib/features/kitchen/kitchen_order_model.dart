class KitchenOrder {
  final String orderId;
  final String status;
  final DateTime createdAt;

  const KitchenOrder({
    required this.orderId,
    required this.status,
    required this.createdAt,
  });

  KitchenOrder copyWith({
    String? status,
  }) {
    return KitchenOrder(
      orderId: orderId,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
