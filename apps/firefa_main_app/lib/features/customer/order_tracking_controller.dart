import 'order_tracking_ui_model.dart';

class OrderTrackingController {
  final List<OrderTrackingUiModel> _orders = [];

  List<OrderTrackingUiModel> get orders => List.unmodifiable(_orders);

  void add(OrderTrackingUiModel order) {
    _orders.add(order);
  }

  void updateStatus(String orderId, String status) {
    final index = _orders.indexWhere((item) => item.orderId == orderId);
    if (index == -1) return;

    _orders[index] = OrderTrackingUiModel(
      orderId: orderId,
      status: status,
    );
  }
}
