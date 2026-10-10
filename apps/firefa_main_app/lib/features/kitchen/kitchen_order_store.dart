import 'kitchen_order_model.dart';

class KitchenOrderStore {
  final List<KitchenOrder> _orders = [];

  List<KitchenOrder> get orders => List.unmodifiable(_orders);

  void add(KitchenOrder order) {
    _orders.add(order);
  }

  void updateStatus(
    String orderId,
    String status,
  ) {
    final index = _orders.indexWhere(
      (e) => e.orderId == orderId,
    );

    if (index == -1) return;

    _orders[index] = _orders[index].copyWith(
      status: status,
    );
  }

  void clear() {
    _orders.clear();
  }
}
