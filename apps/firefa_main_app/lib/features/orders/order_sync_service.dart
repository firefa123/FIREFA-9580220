import 'offline_order_queue.dart';

class OrderSyncService {
  final OfflineOrderQueue queue;

  OrderSyncService({
    required this.queue,
  });

  Future<void> syncPendingOrders() async {
    final orders = await queue.getOrders();

    for (final order in orders) {
      // API sync handler will be connected here.
      // Pending orders remain stored until successful sync.
    }
  }
}
