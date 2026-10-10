import 'dashboard_live_summary.dart';

class ManagerLiveDashboardAdapter {
  DashboardLiveSummary buildSummary({
    required int kitchenOrders,
    required int offlineQueue,
  }) {
    return DashboardLiveSummary(
      kitchenOrders: kitchenOrders,
      offlineQueue: offlineQueue,
    );
  }
}
