import '../modules/order_models.dart';
import 'operational_analytics_model.dart';

/// Summarizes order throughput and completion duration for the supplied outlet.
class OperationalAnalyticsController {
  OperationalAnalyticsController({required List<FirefaOrder> orders})
      : _orders = List.unmodifiable(orders);

  final List<FirefaOrder> _orders;

  OperationalAnalyticsModel getSummary() {
    final completed = _orders
        .where((order) => order.status == FirefaOrderStatus.completed)
        .toList();
    final measuredDurations = completed
        .where((order) =>
            order.completedAt != null &&
            !order.completedAt!.isBefore(order.createdAt))
        .map((order) =>
            order.completedAt!.difference(order.createdAt).inSeconds / 60)
        .toList();

    final averageMinutes = measuredDurations.isEmpty
        ? 0.0
        : measuredDurations.reduce((sum, minutes) => sum + minutes) /
            measuredDurations.length;

    return OperationalAnalyticsModel(
      totalOrders: _orders.length,
      completedOrders: completed.length,
      averageCompletionMinutes: averageMinutes,
    );
  }
}
