import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';
import 'package:firefa_main_app/features/orders/repositories/in_memory_order_repository.dart';

void main() {
  test('repository accepts valid monotonic checkout and payment transitions', () async {
    final repository = InMemoryOrderRepository();
    final createdAt = DateTime.utc(2026, 10, 13);
    final awaiting = TransactionModel(
      id: 'trx-1',
      createdAt: createdAt,
      totalAmount: 25000,
      status: TransactionStatus.awaitingPayment,
      itemIds: const ['coffee'],
    );
    await repository.saveTransaction(awaiting);
    final pendingPayment = PaymentModel(
      id: 'pay-1',
      transactionId: 'trx-1',
      method: PaymentMethod.qris,
      status: PaymentStatus.pending,
      amount: 25000,
      createdAt: createdAt,
    );
    await repository.savePayment(pendingPayment);
    await repository.savePayment(
      pendingPayment.copyWith(status: PaymentStatus.paid),
    );
    final paid = awaiting.copyWith(status: TransactionStatus.paid);
    await repository.saveTransaction(paid);
    await repository.saveTransaction(
      paid.copyWith(status: TransactionStatus.completed),
    );

    expect(
      (await repository.getTransaction('trx-1'))!.status,
      TransactionStatus.completed,
    );
  });

  test('repository persists safe cancellation before payment settlement', () async {
    final repository = InMemoryOrderRepository();
    final createdAt = DateTime.utc(2026, 10, 13);
    final awaiting = TransactionModel(
      id: 'trx-cancel',
      createdAt: createdAt,
      totalAmount: 8000,
      status: TransactionStatus.awaitingPayment,
      itemIds: const ['tea'],
    );
    await repository.saveTransaction(awaiting);
    final pendingPayment = PaymentModel(
      id: 'pay-cancel',
      transactionId: awaiting.id,
      method: PaymentMethod.cash,
      status: PaymentStatus.pending,
      amount: 8000,
      createdAt: createdAt,
    );
    await repository.savePayment(pendingPayment);
    await repository.savePayment(
      pendingPayment.copyWith(status: PaymentStatus.failed),
    );
    await repository.saveTransaction(
      awaiting.copyWith(status: TransactionStatus.cancelled),
    );

    expect(
      (await repository.getTransaction(awaiting.id))!.status,
      TransactionStatus.cancelled,
    );
  });

  test('repository rejects identity collisions and invalid state transitions', () async {
    final repository = InMemoryOrderRepository();
    final createdAt = DateTime.utc(2026, 10, 13);
    final awaiting = TransactionModel(
      id: 'trx-1',
      createdAt: createdAt,
      totalAmount: 25000,
      status: TransactionStatus.awaitingPayment,
      itemIds: const ['coffee'],
    );
    await repository.saveTransaction(awaiting);

    await expectLater(
      repository.saveTransaction(awaiting.copyWith(totalAmount: 99999)),
      throwsStateError,
    );
    await expectLater(
      repository.saveTransaction(
        awaiting.copyWith(status: TransactionStatus.completed),
      ),
      throwsStateError,
    );
    await expectLater(
      repository.savePayment(PaymentModel(
        id: 'pay-missing',
        transactionId: 'missing',
        method: PaymentMethod.cash,
        status: PaymentStatus.pending,
        amount: 25000,
        createdAt: DateTime.utc(2026, 10, 13),
      )),
      throwsStateError,
    );
    await expectLater(
      repository.savePayment(PaymentModel(
        id: 'pay-wrong-amount',
        transactionId: 'trx-1',
        method: PaymentMethod.cash,
        status: PaymentStatus.pending,
        amount: 1000,
        createdAt: DateTime.utc(2026, 10, 13),
      )),
      throwsStateError,
    );
  });
}
