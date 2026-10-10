import 'conflict_management.dart';
import 'conflict_store.dart';

/// Bridge between hybrid sync events and conflict management.
/// This layer only routes conflict events. It does not mutate business data.
class FirefaHybridSyncConflictBridge {
  final FirefaConflictManager manager;
  final FirefaConflictStore store;

  const FirefaHybridSyncConflictBridge({
    this.manager = const FirefaConflictManager(),
    required this.store,
  });

  Future<bool> processServerMismatch({
    required FirefaSyncEntry local,
    required String outletId,
    required String orderId,
    required Map<String, dynamic> serverSnapshot,
    FirefaConflictKind kind = FirefaConflictKind.concurrentEdit,
  }) async {
    final conflict = manager.detect(
      local: local,
      serverOutletId: outletId,
      serverOrderId: orderId,
      serverSnapshot: serverSnapshot,
      kind: kind,
    );

    if (conflict == null) return false;

    await store.add(conflict);
    return true;
  }
}
