import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/models/cart_item_model.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/receipt_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';
import 'package:firefa_main_app/features/orders/utils/transaction_receipt_formatter.dart';

void main() {
  final transaction = TransactionModel(
    id: 'TRX-100', createdAt: DateTime(2026, 10, 14),
    totalAmount: 45000, status: TransactionStatus.completed,
    itemIds: const ['rice', 'tea'],
  );
  final payment = PaymentModel(
    id: 'PAY-100', transactionId: 'TRX-100',
    method: PaymentMethod.cash, status: PaymentStatus.paid,
    amount: 45000, createdAt: DateTime(2026, 10, 14),
  );
  final receipt = ReceiptModel(
    transactionId: 'TRX-100', paymentId: 'PAY-100',
    issuedAt: DateTime(2026, 10, 14, 10, 30),
    totalAmount: 45000, paymentMethod: 'cash',
  );
  final items = [
    CartItemModel(id: 'rice', name: 'Nasi Goreng', price: 30000),
    CartItemModel(id: 'tea', name: 'Tea', price: 15000),
  ];

  test('formats an itemized receipt with matching totals and simulation notice', () {
    final text = TransactionReceiptFormatter.format(
      receipt: receipt, transaction: transaction,
      payment: payment, items: items,
    );
    expect(text, contains('TRX-100'));
    expect(text, contains('PAY-100'));
    expect(text, contains('Nasi Goreng x1'));
    expect(text, contains('Rp 30000'));
    expect(text, contains('TOTAL: Rp 45000'));
    expect(text, contains('LUNAS (SIMULASI LOKAL)'));
    expect(text, contains('Bukan bukti settlement bank.'));
  });

  test('rejects a receipt that does not match its payment', () {
    final mismatched = payment.copyWith(id: 'PAY-OTHER');
    expect(
      () => TransactionReceiptFormatter.format(
        receipt: receipt, transaction: transaction,
        payment: mismatched, items: items,
      ),
      throwsArgumentError,
    );
  });

  test('rejects item totals that differ from the paid amount', () {
    final changedItems = [
      CartItemModel(id: 'rice', name: 'Nasi Goreng', price: 30000),
      CartItemModel(id: 'tea', name: 'Tea', price: 10000),
    ];
    expect(
      () => TransactionReceiptFormatter.format(
        receipt: receipt, transaction: transaction,
        payment: payment, items: changedItems,
      ),
      throwsArgumentError,
    );
  });
}
