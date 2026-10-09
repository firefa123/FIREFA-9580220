import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

void main() {
  FirefaOrder order({
    FirefaOrderStatus status = FirefaOrderStatus.confirmed,
    FirefaPaymentStatus payment = FirefaPaymentStatus.unpaid,
    String outlet = 'outlet-1',
  }) => FirefaOrder(
        id: 'ORD-1001',
        outletId: outlet,
        orderType: 'Dine In',
        tableId: 'A1',
        createdAt: DateTime(2026, 10, 9, 12),
        items: const [
          FirefaOrderItem(productName: 'Kopi', quantity: 2, unitPrice: 20000),
        ],
        subtotal: 40000,
        discount: 5000,
        tax: 3500,
        service: 0,
        total: 38500,
        status: status,
        paymentStatus: payment,
      );

  test('order JSON round trip retains outlet and financial snapshot', () {
    final restored = FirefaOrder.fromJson(order().toJson());
    expect(restored.outletId, 'outlet-1');
    expect(restored.tableId, 'A1');
    expect(restored.total, 38500);
    expect(restored.itemCount, 2);
    expect(restored.items.single.total, 40000);
  });

  test('unpaid served order cannot complete', () {
    final current = order(status: FirefaOrderStatus.served);
    expect(current.canComplete, false);
    expect(current.advanceStatus(), false);
    expect(current.status, FirefaOrderStatus.served);
  });

  test('paid served order completes', () {
    final current = order(status: FirefaOrderStatus.served);
    expect(current.markPaid(), true);
    expect(current.advanceStatus(), true);
    expect(current.status, FirefaOrderStatus.completed);
  });

  test('cancelled orders cannot be paid or advanced', () {
    final current = order();
    expect(current.cancel(), true);
    expect(current.markPaid(), false);
    expect(current.advanceStatus(), false);
  });

  test('paid orders cannot be cancelled', () {
    final current = order(payment: FirefaPaymentStatus.paid);
    expect(current.cancel(), false);
    expect(current.status, FirefaOrderStatus.confirmed);
  });

  test('order item details survive serialization', () {
    const item = FirefaOrderItem(
      productName: 'Teh', quantity: 3, unitPrice: 12000, details: 'Less ice',
    );
    final restored = FirefaOrderItem.fromJson(item.toJson());
    expect(restored.details, 'Less ice');
    expect(restored.total, 36000);
  });
}
