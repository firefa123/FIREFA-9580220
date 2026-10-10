import 'sales_analytics_model.dart';

class AnalyticsController {
  SalesAnalyticsModel getSummary() {
    return const SalesAnalyticsModel(
      totalRevenue: 0,
      totalOrders: 0,
      completedOrders: 0,
    );
  }
}
