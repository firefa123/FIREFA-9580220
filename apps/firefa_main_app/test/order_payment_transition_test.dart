import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

void main() {
  test('payment is idempotent and a paid order cannot be cancelled', () {
    final order = FirefaOrder(
      id: 'ORD-PAYMENT-1',
      outletId: 'outlet-payments',
      orderType: 'Take Away',
      tableId: null,
      createdAt: DateTime.utc(2026, 10, 13),
      items: const [
        FirefaOrderItem(productName: 'Coffee', quantity: 2, unitPrice: 15000),
      ],
      subtotal: 30000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 30000,
    );

    expect(order.paymentStatus, FirefaPaymentStatus.unpaid);
    expect(order.markPaid(), isTrue);
    expect(order.paymentStatus, FirefaPaymentStatus.paid);
    expect(order.markPaid(), isFalse);
    expect(order.cancel(), isFalse);
    expect(order.status, isNot(FirefaOrderStatus.cancelled));
  });

  test('an order cannot complete until it is paid and served', () {
    final order = FirefaOrder(
      id: 'ORD-PAYMENT-2',
      outletId: 'outlet-payments',
      orderType: 'Take Away',
      tableId: null,
      createdAt: DateTime.utc(2026, 10, 13),
      items: const [
        FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 8000),
      ],
      subtotal: 8000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 8000,
    );

    expect(order.advanceStatus(), isTrue);
    expect(order.advanceStatus(), isTrue);
    expect(order.advanceStatus(), isTrue);
    expect(order.advanceStatus(), isTrue);
    expect(order.status, FirefaOrderStatus.served);
    expect(order.advanceStatus(), isFalse);

    expect(order.markPaid(), isTrue);
    expect(order.advanceStatus(), isTrue);
    expect(order.status, FirefaOrderStatus.completed);
    expect(order.canComplete, isFalse);
  });
}
