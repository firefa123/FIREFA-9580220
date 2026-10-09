import 'dashboard_live_summary.dart';

class ManagerLiveDashboardAdapter {
  DashboardLiveSummary buildSummary({
    required int totalOrders,
    required int preparing,
    required int ready,
    required int offlineQueue,
  }) {
    return DashboardLiveSummary(
      totalOrders: totalOrders,
      preparing: preparing,
      ready: ready,
      offlineQueue: offlineQueue,
    );
  }
}
