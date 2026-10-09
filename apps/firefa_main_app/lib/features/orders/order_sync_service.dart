import 'offline_order_model.dart';
import 'offline_order_queue.dart';

class OrderSyncService {
  final OfflineOrderQueue queue;

  OrderSyncService({
    required this.queue,
  });

  Future<void> syncPendingOrders(
    List<OfflineOrder> orders,
  ) async {
    for (final order in orders) {
      // API sync handler will be connected here.
      // Pending orders remain stored until successful sync.
      await Future<void>.value(order.orderId);
    }
  }

  Future<void> syncAll() async {
    final orders = await queue.getPendingOrders();
    await syncPendingOrders(orders);
  }
}
