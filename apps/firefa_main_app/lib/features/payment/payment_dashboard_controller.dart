import 'payment_dashboard_model.dart';

class PaymentDashboardController {
  PaymentDashboardModel getSummary() {
    return const PaymentDashboardModel(
      totalTransactions: 0,
      totalRevenue: 0,
      successfulPayments: 0,
    );
  }
}
