import 'operational_analytics_model.dart';

class OperationalAnalyticsController {
  OperationalAnalyticsModel getSummary() {
    return const OperationalAnalyticsModel(
      totalOrders: 0,
      completedOrders: 0,
      averageCompletionMinutes: 0,
    );
  }
}
