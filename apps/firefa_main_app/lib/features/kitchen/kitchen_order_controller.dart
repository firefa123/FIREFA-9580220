import 'kitchen_order_store.dart';

class KitchenOrderController {
  final KitchenOrderStore store;

  KitchenOrderController({
    required this.store,
  });

  int get pendingCount => store.orders.length;

  void startPreparing(String orderId) {
    store.updateStatus(orderId, 'preparing');
  }

  void markReady(String orderId) {
    store.updateStatus(orderId, 'ready');
  }
}
