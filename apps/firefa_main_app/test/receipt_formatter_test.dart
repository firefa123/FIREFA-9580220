import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/receipt_formatter.dart';
import 'package:firefa_main_app/features/modules/settings_store.dart';

void main() {
  final order = FirefaOrder(
    id: 'ORD-1001',
    outletId: 'outlet-001',
    orderType: 'Dine In',
    tableId: 'A01',
    createdAt: DateTime(2026, 10, 9, 10),
    items: const [
      FirefaOrderItem(productName: 'Kopi', quantity: 2, unitPrice: 10000),
    ],
    subtotal: 20000,
    discount: 0,
    tax: 2000,
    service: 0,
    total: 22000,
    paymentStatus: FirefaPaymentStatus.paid,
  );

  test('receipt uses outlet identity and custom preferences', () {
    final result = FirefaReceiptFormatter.format(
      order: order,
      outletName: 'Outlet Utama',
      settings: const FirefaOutletSettings(
        outletId: 'outlet-001',
        address: 'Jalan Mawar',
        contact: '081234',
        receiptFooter: 'Datang kembali',
      ),
    );
    expect(result, contains('Outlet Utama'));
    expect(result, contains('Jalan Mawar'));
    expect(result, contains('081234'));
    expect(result, contains('Datang kembali'));
    expect(result, contains('Pajak: Rp 2000'));
    expect(result, contains('TOTAL: Rp 22000'));
  });

  test('tax preference hides tax line but preserves total', () {
    final result = FirefaReceiptFormatter.format(
      order: order,
      outletName: 'Outlet Utama',
      settings: const FirefaOutletSettings(
        outletId: 'outlet-001',
        showTaxOnReceipt: false,
      ),
    );
    expect(result, isNot(contains('Pajak: Rp')));
    expect(result, contains('TOTAL: Rp 22000'));
    expect(result, contains('sudah termasuk komponen pajak'));
  });

  test('receipt rejects cross-outlet settings', () {
    expect(() => FirefaReceiptFormatter.format(
      order: order,
      outletName: 'Outlet Utama',
      settings: const FirefaOutletSettings(outletId: 'outlet-002'),
    ), throwsArgumentError);
  });
}
