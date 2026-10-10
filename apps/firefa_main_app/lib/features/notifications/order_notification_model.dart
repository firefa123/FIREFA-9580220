class OrderNotification {
  final String orderId;
  final String title;
  final String message;
  final DateTime createdAt;

  const OrderNotification({
    required this.orderId,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
  };
}
