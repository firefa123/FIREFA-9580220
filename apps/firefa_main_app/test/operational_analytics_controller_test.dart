import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/analytics/operational_analytics_controller.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

FirefaOrder makeOrder({
  required String id,
  required DateTime createdAt,
  DateTime? completedAt,
  required FirefaOrderStatus status,
}) {
  return FirefaOrder(
    id: id,
    outletId: 'OUTLET-1',
    orderType: 'Take Away',
    tableId: null,
    createdAt: createdAt,
    completedAt: completedAt,
    items: const [],
    subtotal: 100,
    discount: 0,
    tax: 0,
    service: 0,
    total: 100,
    status: status,
    paymentStatus: FirefaPaymentStatus.paid,
  );
}

void main() {
  group('OperationalAnalyticsController', () {
    test('calculates total orders, completed orders, and average duration', () {
      final start = DateTime(2026, 10, 14, 9);
      final analytics = OperationalAnalyticsController(orders: [
        makeOrder(
          id: 'ORD-1',
          createdAt: start,
          completedAt: start.add(const Duration(minutes: 10)),
          status: FirefaOrderStatus.completed,
        ),
        makeOrder(
          id: 'ORD-2',
          createdAt: start,
          completedAt: start.add(const Duration(minutes: 20)),
          status: FirefaOrderStatus.completed,
        ),
        makeOrder(
          id: 'ORD-3',
          createdAt: start,
          status: FirefaOrderStatus.preparing,
        ),
      ]);

      final summary = analytics.getSummary();

      expect(summary.totalOrders, 3);
      expect(summary.completedOrders, 2);
      expect(summary.averageCompletionMinutes, 15);
    });

    test('returns zero average when no completion duration is recorded', () {
      final summary = OperationalAnalyticsController(orders: [
        makeOrder(
          id: 'ORD-1',
          createdAt: DateTime(2026, 10, 14, 9),
          status: FirefaOrderStatus.completed,
        ),
      ]).getSummary();

      expect(summary.totalOrders, 1);
      expect(summary.completedOrders, 1);
      expect(summary.averageCompletionMinutes, 0);
    });

    test('returns zero totals for an empty order list', () {
      final summary =
          OperationalAnalyticsController(orders: const []).getSummary();

      expect(summary.totalOrders, 0);
      expect(summary.completedOrders, 0);
      expect(summary.averageCompletionMinutes, 0);
    });
  });
}
