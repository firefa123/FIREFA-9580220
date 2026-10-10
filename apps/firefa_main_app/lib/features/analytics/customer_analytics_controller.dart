import 'customer_analytics_model.dart';

class CustomerAnalyticsController {
  CustomerAnalyticsModel getSummary() {
    return const CustomerAnalyticsModel(
      totalCustomers: 0,
      repeatCustomers: 0,
      loyaltyPointsIssued: 0,
    );
  }
}
