import 'payment_controller.dart';
import 'payment_dashboard_model.dart';

/// Builds payment dashboard totals from the transactions already recorded
/// by the payment module. Revenue includes completed payments only.
class PaymentDashboardController {
  PaymentDashboardController(this._paymentController);

  final PaymentController _paymentController;

  PaymentDashboardModel getSummary() {
    final transactions = _paymentController.transactions;
    final completed = _paymentController.completedTransactions;

    final revenue = completed.fold<double>(
      0,
      (total, transaction) => total + transaction.amount,
    );

    return PaymentDashboardModel(
      totalTransactions: transactions.length,
      totalRevenue: revenue,
      successfulPayments: completed.length,
    );
  }
}
