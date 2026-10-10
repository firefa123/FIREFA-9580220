import '../kitchen/kitchen_order_store.dart';
import '../orders/offline_order_queue.dart';

class DashboardDataSource {
  final KitchenOrderStore kitchenStore;
  final OfflineOrderQueue offlineQueue;

  DashboardDataSource({
    required this.kitchenStore,
    required this.offlineQueue,
  });

  Future<Map<String, int>> loadOverview() async {
    final offline = await offlineQueue.getOrders();

    return {
      'kitchenOrders': kitchenStore.orders.length,
      'offlineQueue': offline.length,
    };
  }
}
