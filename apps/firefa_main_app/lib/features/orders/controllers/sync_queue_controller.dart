import '../models/transaction_model.dart';
import '../repositories/order_repository.dart';

typedef TransactionSyncHandler = Future<void> Function(
  TransactionModel transaction,
);

class SyncQueueController {
  final OrderRepository repository;

  const SyncQueueController({
    required this.repository,
  });

  Future<int> syncPending(TransactionSyncHandler syncHandler) async {
    final pendingTransactions = await repository.getPendingSyncTransactions();
    var syncedCount = 0;

    for (final transaction in pendingTransactions) {
      try {
        await syncHandler(transaction);
        await repository.markTransactionSynced(transaction.id);
        syncedCount++;
      } catch (_) {
        continue;
      }
    }

    return syncedCount;
  }
}
