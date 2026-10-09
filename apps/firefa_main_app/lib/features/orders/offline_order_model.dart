class OfflineOrder {
  final String orderId;
  final String outletId;
  final String status;
  final DateTime createdAt;
  final List<Map<String, dynamic>> items;

  OfflineOrder({
    required this.orderId,
    required this.outletId,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'outletId': outletId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'items': items,
    };
  }

  factory OfflineOrder.fromJson(Map<String, dynamic> json) {
    return OfflineOrder(
      orderId: json['orderId'],
      outletId: json['outletId'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      items: List<Map<String, dynamic>>.from(json['items']),
    );
  }
}
