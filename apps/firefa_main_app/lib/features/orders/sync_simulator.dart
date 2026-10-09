import 'offline_order_queue.dart';
import 'offline_order_model.dart';

class SyncSimulator {
  final OfflineOrderQueue queue;

  SyncSimulator({
    required this.queue,
  });

  Future<int> simulateSync() async {
    final orders = await queue.getPendingOrders();

    if (orders.isEmpty) {
      return 0;
    }

    for (final OfflineOrder order in orders) {
      await Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      await queue.remove(order.orderId);
    }

    return orders.length;
  }
}
