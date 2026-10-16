import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/cashier_shift_page.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paid order persists payment method, cash portion, and paid timestamp', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    await store.initialize();

    final order = store.createOrder(
      outletId: 'PAYMENT-TEST',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Coffee',
          productId: 'coffee',
          quantity: 1,
          unitPrice: 50000,
        ),
      ],
      subtotal: 50000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 50000,
    );

    final beforePayment = DateTime.now();
    expect(
      await store.markPaidAndPersist(
        'PAYMENT-TEST',
        order.id,
        paymentMethod: 'Split:QRIS',
        cashPaidAmount: 20000,
      ),
      isTrue,
    );
    await store.waitForPendingSave();

    expect(order.paymentStatus, FirefaPaymentStatus.paid);
    expect(order.paymentVerificationStatus, FirefaPaymentVerificationStatus.reported);
    expect(order.paymentMethod, 'Split:QRIS');
    expect(order.cashPaidAmount, 20000);
    expect(order.paidAt, isNotNull);
    expect(order.paidAt!.isBefore(beforePayment), isFalse);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('firefa_orders_outbox_v2');
    expect(raw, isNotNull);
    final snapshot = jsonDecode(raw!) as Map<String, dynamic>;
    final savedOrder = (snapshot['orders'] as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .singleWhere((entry) => entry['id'] == order.id);
    expect(savedOrder['paymentMethod'], 'Split:QRIS');
    expect(savedOrder['cashPaidAmount'], 20000);
    expect(savedOrder['paidAt'], isNotNull);
    expect(savedOrder['paymentVerificationStatus'], FirefaPaymentVerificationStatus.reported.name);
  });

  test('legacy order JSON without payment details remains readable', () {
    final order = FirefaOrder(
      id: 'ORD-LEGACY',
      outletId: 'LEGACY',
      orderType: 'Take Away',
      tableId: null,
      createdAt: DateTime(2026, 10, 14, 8),
      items: const [
        FirefaOrderItem(
          productName: 'Tea',
          quantity: 1,
          unitPrice: 10000,
        ),
      ],
      subtotal: 10000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 10000,
    );
    final json = order.toJson()
      ..remove('paidAt')
      ..remove('paymentMethod')
      ..remove('cashPaidAmount');

    final restored = FirefaOrder.fromJson(json);
    expect(restored.paidAt, isNull);
    expect(restored.paymentMethod, isNull);
    expect(restored.cashPaidAmount, 0);
  });

  test('full cash refund is recorded and reduces shift cash reconciliation', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    await store.initialize();
    final order = store.createOrder(
      outletId: 'REFUND-TEST',
      orderType: 'Take Away',
      tableId: null,
      items: const [FirefaOrderItem(productName: 'Meal', quantity: 1, unitPrice: 25000)],
      subtotal: 25000, discount: 0, tax: 0, service: 0, total: 25000,
    );
    expect(await store.markPaidAndPersist('REFUND-TEST', order.id, paymentMethod: 'Cash', cashPaidAmount: 25000), isTrue);
    expect(await store.applyServerPaymentVerification('REFUND-TEST', order.id, verifiedBy: 'owner-test'), isTrue);
    expect(await store.refundPaidAndPersist('REFUND-TEST', order.id, refundMethod: 'Cash', reason: 'Pesanan salah'), isTrue);
    expect(await store.applyServerRefundVerification('REFUND-TEST', order.id, 0, verifiedBy: 'owner-test'), isTrue);
    await store.waitForPendingSave();
    expect(order.paymentStatus, FirefaPaymentStatus.refunded);
    expect(order.refundRecords.single.verificationStatus, FirefaRefundVerificationStatus.verified);
    expect(order.cashRefundAmount, 25000);
    expect(calculateCashRefundsForShift(
      orders: [order],
      openedAt: DateTime(2026, 10, 16, 0),
      closedAt: DateTime(2026, 10, 17, 0),
    ), 25000);
    expect(order.refundReason, 'Pesanan salah');
    expect(order.refundedAt, isNotNull);
    expect(await store.markPaidAndPersist('REFUND-TEST', order.id, paymentMethod: 'Cash', cashPaidAmount: 25000), isFalse);
    expect(await store.cancelAndRestoreStock('REFUND-TEST', order.id), isFalse);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('firefa_orders_outbox_v2');
    expect(raw, isNotNull);
    final saved = (jsonDecode(raw!) as Map<String, dynamic>)['orders'] as List;
    final savedRefund = Map<String, dynamic>.from(saved.singleWhere((entry) => (entry as Map)['id'] == order.id) as Map);
    expect(savedRefund['paymentStatus'], FirefaPaymentStatus.paid.name);
    expect(savedRefund['refundReason'], 'Pesanan salah');
    expect(savedRefund['cashRefundAmount'], 25000);
    expect(await store.refundPaidAndPersist('REFUND-TEST', order.id, refundMethod: 'Cash', reason: 'Duplikat'), isFalse);
  });

  test('shift cash sales counts cash and split cash only within shift window', () {
    final opened = DateTime(2026, 10, 14, 9);
    final closed = DateTime(2026, 10, 14, 17);
    FirefaOrder paidOrder(String id, DateTime paidAt, String method, int cash) {
      return FirefaOrder(
        id: id,
        outletId: 'SHIFT-TEST',
        orderType: 'Take Away',
        tableId: null,
        createdAt: paidAt.subtract(const Duration(minutes: 2)),
        paidAt: paidAt,
        paymentMethod: method,
        cashPaidAmount: cash,
        items: const [
          FirefaOrderItem(productName: 'Item', quantity: 1, unitPrice: 1000),
        ],
        subtotal: 1000,
        discount: 0,
        tax: 0,
        service: 0,
        total: 1000,
        paymentStatus: FirefaPaymentStatus.paid,
      );
    }

    final orders = [
      paidOrder('cash', DateTime(2026, 10, 14, 10), 'Cash', 10000),
      paidOrder('split', DateTime(2026, 10, 14, 11), 'Split:QRIS', 4000),
      paidOrder('qris', DateTime(2026, 10, 14, 12), 'QRIS', 0),
      paidOrder('before', DateTime(2026, 10, 14, 8), 'Cash', 9000),
      paidOrder('after', DateTime(2026, 10, 14, 18), 'Cash', 7000),
    ];

    final cashRefund = paidOrder('cash-refund', DateTime(2026, 10, 14, 10), 'Cash', 10000)
      ..paymentStatus = FirefaPaymentStatus.refunded
      ..refundedAt = DateTime(2026, 10, 14, 15)
      ..cashRefundAmount = 6000;
    expect(
      calculateCashSalesForShift(
        orders: [...orders, cashRefund],
        openedAt: opened,
        closedAt: closed,
      ),
      24000,
    );
    expect(
      calculateCashRefundsForShift(
        orders: [...orders, cashRefund],
        openedAt: opened,
        closedAt: closed,
      ),
      6000,
    );
  });
}
