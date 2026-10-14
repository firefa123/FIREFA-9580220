import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

FirefaOrder sampleOrder() => FirefaOrder(
  id: 'ORD-PHASE2',
  outletId: 'OUTLET-PHASE2',
  orderType: 'Take Away',
  tableId: null,
  createdAt: DateTime(2026, 10, 14, 9),
  items: const [FirefaOrderItem(productName: 'Coffee', productId: 'coffee', quantity: 2, unitPrice: 25000, details: 'Large • Oat Milk • Note: less ice')],
  subtotal: 50000,
  discount: 0,
  tax: 0,
  service: 0,
  total: 50000,
);

void main() {
  group('Phase 2 transaction lifecycle', () {
    test('BON remains an outstanding unpaid receivable until collected', () {
      final order = sampleOrder();
      expect(order.markBon(), isTrue);
      expect(order.paymentMethod, 'BON');
      expect(order.paymentStatus, FirefaPaymentStatus.unpaid);
      expect(order.paidAt, isNull);
      expect(order.markPaid(method: 'Cash', cashAmount: order.total), isTrue);
      expect(order.paymentStatus, FirefaPaymentStatus.paid);
      expect(order.paymentMethod, 'Cash');
      expect(order.paidAt, isNotNull);
    });

    test('partial refunds accumulate with reasons and remaining refundable amount', () {
      final order = sampleOrder();
      expect(order.markPaid(method: 'QRIS', cashAmount: 0), isTrue);
      expect(order.markRefunded(method: 'Cash', reason: 'Item rusak', amount: 10000), isTrue);
      expect(order.paymentStatus, FirefaPaymentStatus.paid);
      expect(order.refundAmount, 10000);
      expect(order.cashRefundAmount, 10000);
      expect(order.refundableAmount, 40000);
      expect(order.refundRecords, hasLength(1));
      expect(order.markRefunded(method: 'Non-tunai', reason: 'Item tertinggal', amount: 15000), isTrue);
      expect(order.refundAmount, 25000);
      expect(order.cashRefundAmount, 10000);
      expect(order.refundableAmount, 25000);
      expect(order.refundRecords, hasLength(2));
      expect(order.markRefunded(method: 'Cash', reason: 'Melebihi sisa', amount: 25001), isFalse);
    });

    test('full refund can follow partial refunds and blocks additional refunds', () {
      final order = sampleOrder()..markPaid(method: 'Transfer', cashAmount: 0);
      expect(order.markRefunded(method: 'Cash', reason: 'Pertama', amount: 20000), isTrue);
      expect(order.markRefunded(method: 'Non-tunai', reason: 'Sisa', amount: 30000), isTrue);
      expect(order.paymentStatus, FirefaPaymentStatus.refunded);
      expect(order.refundAmount, order.total);
      expect(order.refundableAmount, 0);
      expect(order.markRefunded(method: 'Cash', reason: 'Duplikat', amount: 1), isFalse);
    });

    test('refund ledger and BON survive JSON round trip', () {
      final order = sampleOrder()..markBon();
      order.markPaid(method: 'Transfer', cashAmount: 0);
      order.markRefunded(method: 'Cash', reason: 'Uji audit', amount: 5000);
      final restored = FirefaOrder.fromJson(order.toJson());
      expect(restored.paymentStatus, FirefaPaymentStatus.paid);
      expect(restored.refundAmount, 5000);
      expect(restored.refundableAmount, 45000);
      expect(restored.refundRecords.single.reason, 'Uji audit');
      expect(restored.refundRecords.single.amount, 5000);
    });

    test('legacy fully-refunded order JSON without a refund ledger remains readable', () {
      final json = sampleOrder().toJson()
        ..['paymentStatus'] = FirefaPaymentStatus.refunded.name
        ..['refundMethod'] = 'Cash'
        ..['refundReason'] = 'Legacy'
        ..['refundedAt'] = DateTime(2026, 10, 14, 10).toIso8601String()
        ..['cashRefundAmount'] = 50000;
      final restored = FirefaOrder.fromJson(json);
      expect(restored.refundAmount, 50000);
      expect(restored.refundRecords.single.amount, 50000);
      expect(restored.refundRecords.single.reason, 'Legacy');
    });
  });
}
