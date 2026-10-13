import 'platform_analytics_model.dart';

class PlatformAnalyticsController {
  PlatformAnalyticsModel getSummary() {
    return const PlatformAnalyticsModel(
      totalTenants: 0,
      totalOutlets: 0,
      totalUsers: 0,
      totalTransactions: 0,
    );
  }
}
