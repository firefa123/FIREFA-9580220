import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/analytics/analytics_controller.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

FirefaOrder makeOrder({
  required String id,
  required int total,
  required FirefaOrderStatus status,
  required FirefaPaymentStatus paymentStatus,
}) {
  return FirefaOrder(
    id: id,
    outletId: 'OUTLET-1',
    orderType: 'Take Away',
    tableId: null,
    createdAt: DateTime(2026, 10, 13),
    items: const [],
    subtotal: total,
    discount: 0,
    tax: 0,
    service: 0,
    total: total,
    status: status,
    paymentStatus: paymentStatus,
  );
}

void main() {
  group('AnalyticsController', () {
    test('calculates order count, completed count, and paid revenue', () {
      final analytics = AnalyticsController(orders: [
        makeOrder(
          id: 'ORD-1',
          total: 120,
          status: FirefaOrderStatus.completed,
          paymentStatus: FirefaPaymentStatus.paid,
        ),
        makeOrder(
          id: 'ORD-2',
          total: 80,
          status: FirefaOrderStatus.served,
          paymentStatus: FirefaPaymentStatus.paid,
        ),
        makeOrder(
          id: 'ORD-3',
          total: 60,
          status: FirefaOrderStatus.confirmed,
          paymentStatus: FirefaPaymentStatus.unpaid,
        ),
      ]);

      final summary = analytics.getSummary();

      expect(summary.totalOrders, 3);
      expect(summary.completedOrders, 1);
      expect(summary.totalRevenue, 200);
    });

    test('returns zero totals for an empty order list', () {
      final summary = AnalyticsController(orders: const []).getSummary();

      expect(summary.totalOrders, 0);
      expect(summary.completedOrders, 0);
      expect(summary.totalRevenue, 0);
    });
  });
}
