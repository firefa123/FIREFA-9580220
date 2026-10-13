import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';
import 'package:firefa_main_app/features/orders/repositories/local_order_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TransactionModel transaction({
    String id = 'trx-1',
    double amount = 25000,
    TransactionStatus status = TransactionStatus.awaitingPayment,
    SyncStatus syncStatus = SyncStatus.pending,
  }) {
    return TransactionModel(
      id: id,
      createdAt: DateTime.utc(2026, 10, 13),
      totalAmount: amount,
      status: status,
      syncStatus: syncStatus,
      itemIds: const ['coffee'],
    );
  }

  PaymentModel payment({
    String id = 'pay-1',
    String transactionId = 'trx-1',
    double amount = 25000,
    PaymentStatus status = PaymentStatus.pending,
  }) {
    return PaymentModel(
      id: id,
      transactionId: transactionId,
      method: PaymentMethod.qris,
      status: status,
      amount: amount,
      createdAt: DateTime.utc(2026, 10, 13),
    );
  }

  test('transaction and payment survive repository recreation', () async {
    final first = LocalOrderRepository();
    final awaiting = transaction();
    await first.saveTransaction(awaiting);
    await first.savePayment(payment());
    await first.savePayment(payment(status: PaymentStatus.paid));
    await first.saveTransaction(
      transaction(status: TransactionStatus.paid),
    );
    await first.saveTransaction(
      transaction(status: TransactionStatus.completed),
    );

    final second = LocalOrderRepository();
    final restored = await second.getTransaction('trx-1');
    expect(restored!.status, TransactionStatus.completed);
    expect(restored.totalAmount, 25000);

    final prefs = await SharedPreferences.getInstance();
    final snapshot = jsonDecode(prefs.getString(LocalOrderRepository.storageKey)!)
        as Map<String, dynamic>;
    expect(snapshot['version'], 1);
    expect(snapshot['transactions'], hasLength(1));
    expect(snapshot['payments'], hasLength(1));
    expect(snapshot['payments'].single['status'], 'paid');
  });

  test('conflicting updates are rejected without changing persisted snapshot', () async {
    final repository = LocalOrderRepository();
    await repository.saveTransaction(transaction());
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString(LocalOrderRepository.storageKey);

    await expectLater(
      repository.saveTransaction(transaction(amount: 99999)),
      throwsStateError,
    );
    await expectLater(
      repository.saveTransaction(
        transaction(status: TransactionStatus.completed),
      ),
      throwsStateError,
    );
    expect(prefs.getString(LocalOrderRepository.storageKey), before);
    expect((await repository.getTransaction('trx-1'))!.status,
        TransactionStatus.awaitingPayment);
  });

  test('payment must reference an existing transaction and matching amount', () async {
    final repository = LocalOrderRepository();
    await expectLater(
      repository.savePayment(payment(transactionId: 'missing')),
      throwsStateError,
    );
    await repository.saveTransaction(transaction());
    await expectLater(
      repository.savePayment(payment(amount: 1)),
      throwsStateError,
    );
    expect(await repository.getTransaction('trx-1'), isNotNull);
  });

  test('corrupt snapshot is rejected and a corrected snapshot can be retried', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      LocalOrderRepository.storageKey,
      jsonEncode({
        'version': 1,
        'transactions': [
          {
            'id': 'bad',
            'createdAt': 'not-a-date',
            'totalAmount': 10,
            'status': 'unknown',
            'syncStatus': 'pending',
            'itemIds': ['coffee'],
          },
        ],
        'payments': [],
      }),
    );
    final repository = LocalOrderRepository();
    await expectLater(repository.initialize(), throwsFormatException);

    await prefs.remove(LocalOrderRepository.storageKey);
    await expectLater(repository.initialize(), completes);
    expect(await repository.getTransaction('bad'), isNull);
  });
}
