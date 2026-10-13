import '../modules/order_models.dart';
import 'sales_analytics_model.dart';

/// Calculates sales totals from the orders supplied by the active outlet.
class AnalyticsController {
  AnalyticsController({required List<FirefaOrder> orders})
      : _orders = List.unmodifiable(orders);

  final List<FirefaOrder> _orders;

  SalesAnalyticsModel getSummary() {
    final completedOrders = _orders
        .where((order) => order.status == FirefaOrderStatus.completed)
        .length;
    final paidOrders = _orders
        .where((order) => order.paymentStatus == FirefaPaymentStatus.paid);

    final revenue = paidOrders.fold<int>(
      0,
      (total, order) => total + order.total,
    );

    return SalesAnalyticsModel(
      totalRevenue: revenue.toDouble(),
      totalOrders: _orders.length,
      completedOrders: completedOrders,
    );
  }
}
