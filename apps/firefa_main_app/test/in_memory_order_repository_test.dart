import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';
import 'package:firefa_main_app/features/orders/repositories/in_memory_order_repository.dart';

TransactionModel transaction({
  String id = 'TRX-1',
  double amount = 12000,
  SyncStatus syncStatus = SyncStatus.pending,
  List<String> itemIds = const ['item-1'],
}) {
  return TransactionModel(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    totalAmount: amount,
    status: TransactionStatus.awaitingPayment,
    syncStatus: syncStatus,
    itemIds: itemIds,
  );
}

PaymentModel payment({
  String id = 'PAY-1',
  String transactionId = 'TRX-1',
  double amount = 12000,
}) {
  return PaymentModel(
    id: id,
    transactionId: transactionId,
    method: PaymentMethod.cash,
    status: PaymentStatus.pending,
    amount: amount,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('InMemoryOrderRepository', () {
    test('saves and retrieves normalized transaction ID', () async {
      final repository = InMemoryOrderRepository();
      await repository.saveTransaction(transaction(id: ' TRX-1 '));

      expect((await repository.getTransaction(' TRX-1 '))?.id, 'TRX-1');
    });

    test('rejects blank transaction ID and invalid total', () async {
      final repository = InMemoryOrderRepository();
      await expectLater(
        repository.saveTransaction(transaction(id: ' ')),
        throwsArgumentError,
      );
      await expectLater(
        repository.saveTransaction(transaction(amount: double.infinity)),
        throwsArgumentError,
      );
    });

    test('saved item IDs cannot be mutated through original list', () async {
      final repository = InMemoryOrderRepository();
      final ids = <String>['item-1'];
      await repository.saveTransaction(transaction(itemIds: ids));
      ids.add('item-2');

      expect((await repository.getTransaction('TRX-1'))?.itemIds, ['item-1']);
    });

    test('returns only transactions not yet synced', () async {
      final repository = InMemoryOrderRepository();
      await repository.saveTransaction(transaction(id: 'pending'));
      await repository.saveTransaction(
        transaction(id: 'synced', syncStatus: SyncStatus.synced),
      );

      expect(
        (await repository.getPendingSyncTransactions()).map((item) => item.id),
        ['pending'],
      );
    });

    test('marking unknown transaction synced is safe', () async {
      final repository = InMemoryOrderRepository();
      await repository.markTransactionSynced('missing');
      expect(await repository.getTransaction('missing'), isNull);
    });

    test('marks an existing transaction synced', () async {
      final repository = InMemoryOrderRepository();
      await repository.saveTransaction(transaction());
      await repository.markTransactionSynced(' TRX-1 ');

      expect(
        (await repository.getTransaction('TRX-1'))?.syncStatus,
        SyncStatus.synced,
      );
      expect(await repository.getPendingSyncTransactions(), isEmpty);
    });

    test('saves payment with normalized identifiers', () async {
      final repository = InMemoryOrderRepository();
      await repository.savePayment(
        payment(id: ' PAY-1 ', transactionId: ' TRX-1 '),
      );
    });

    test('rejects blank payment IDs and invalid amount', () async {
      final repository = InMemoryOrderRepository();
      await expectLater(
        repository.savePayment(payment(id: ' ')),
        throwsArgumentError,
      );
      await expectLater(
        repository.savePayment(payment(amount: double.nan)),
        throwsArgumentError,
      );
    });
  });
}
