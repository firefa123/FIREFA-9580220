import 'kitchen_order_store.dart';

class KitchenQueueSummary {
  final KitchenOrderStore store;

  KitchenQueueSummary(this.store);

  int get total => store.orders.length;

  int get readyCount => store.orders
      .where((e) => e.status == 'ready')
      .length;

  int get preparingCount => store.orders
      .where((e) => e.status == 'preparing')
      .length;
}
