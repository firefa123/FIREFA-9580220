import 'order_tracking_status.dart';

class OrderTrackingStore {
  final List<OrderTrackingStatus> _orders = [];

  List<OrderTrackingStatus> get orders => List.unmodifiable(_orders);

  void update(OrderTrackingStatus status) {
    _orders.removeWhere(
      (item) => item.orderId == status.orderId,
    );

    _orders.add(status);
  }

  OrderTrackingStatus? find(String orderId) {
    for (final order in _orders) {
      if (order.orderId == orderId) {
        return order;
      }
    }

    return null;
  }
}
