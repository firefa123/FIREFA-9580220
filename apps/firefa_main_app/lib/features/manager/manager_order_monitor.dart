import '../kitchen/kitchen_order_model.dart';

class ManagerOrderMonitor {
  final List<KitchenOrder> orders = [];

  void addOrder(KitchenOrder order) {
    orders.add(order);
  }

  int get totalOrders => orders.length;

  int get preparingCount => orders
      .where((e) => e.status == 'preparing')
      .length;

  int get readyCount => orders
      .where((e) => e.status == 'ready')
      .length;
}
