class OrderTrackingStatus {
  final String orderId;
  final String status;
  final DateTime updatedAt;

  const OrderTrackingStatus({
    required this.orderId,
    required this.status,
    required this.updatedAt,
  });

  bool get isReady => status == 'ready';

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'status': status,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
