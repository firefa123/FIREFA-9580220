import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/analytics/customer_analytics_controller.dart';
import 'package:firefa_main_app/features/customer/customer_loyalty_model.dart';

void main() {
  group('CustomerAnalyticsController', () {
    test('counts unique customers, repeat customers, and loyalty points', () {
      final summary = CustomerAnalyticsController(
        loyaltyRecords: const [
          CustomerLoyaltyModel(
            customerId: 'C-1',
            points: 15,
            rewardCount: 1,
          ),
          CustomerLoyaltyModel(
            customerId: 'C-2',
            points: 20,
            rewardCount: 0,
          ),
          // A customer present in both sources must only be counted once.
          CustomerLoyaltyModel(
            customerId: 'C-3',
            points: 5,
            rewardCount: 0,
          ),
        ],
        completedOrdersByCustomer: const {
          'C-1': 3,
          'C-3': 1,
          'C-4': 2,
          '': 5,
          'C-5': 0,
        },
      ).getSummary();

      expect(summary.totalCustomers, 4);
      expect(summary.repeatCustomers, 2);
      expect(summary.loyaltyPointsIssued, 40);
    });

    test('returns zero metrics when no customer data is supplied', () {
      final summary = CustomerAnalyticsController().getSummary();

      expect(summary.totalCustomers, 0);
      expect(summary.repeatCustomers, 0);
      expect(summary.loyaltyPointsIssued, 0);
    });

    test('rejects negative completed order counts', () {
      expect(
        () => CustomerAnalyticsController(
          completedOrdersByCustomer: const {'C-1': -1},
        ),
        throwsArgumentError,
      );
    });
  });
}
