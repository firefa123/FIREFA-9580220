import 'dashboard_order_overview.dart';

class DashboardOrderController {
  DashboardOrderOverview buildOverview({
    required int total,
    required int preparing,
    required int ready,
    required int offline,
  }) {
    return DashboardOrderOverview(
      totalOrders: total,
      preparingOrders: preparing,
      readyOrders: ready,
      offlineQueue: offline,
    );
  }
}
