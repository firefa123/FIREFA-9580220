import 'offline_order_queue.dart';
import 'order_sync_service.dart';

class AutoSyncManager {
  final OfflineOrderQueue queue;
  final OrderSyncService syncService;

  AutoSyncManager({
    required this.queue,
    required this.syncService,
  });

  Future<void> onConnectionRestored() async {
    final pending = await queue.getPendingOrders();

    if (pending.isEmpty) return;

    await syncService.syncPendingOrders(pending);
  }
}
