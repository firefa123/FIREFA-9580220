import 'connectivity_monitor.dart';
import 'auto_sync_manager.dart';

class OrderSyncTrigger {
  final ConnectivityMonitor monitor;
  final AutoSyncManager syncManager;

  OrderSyncTrigger({
    required this.monitor,
    required this.syncManager,
  });

  void start() {
    monitor.statusStream.listen((online) {
      if (online) {
        syncManager.onConnectionRestored();
      }
    });
  }
}
