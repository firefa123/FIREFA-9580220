enum OrderStatus {
  waiting,
  preparing,
  completed,
}

class OrderModel {
  final String id;
  final String type;
  final int total;
  final OrderStatus status;

  const OrderModel({
    required this.id,
    required this.type,
    required this.total,
    required this.status,
  });
}
