import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/payment/payment_controller.dart';
import 'package:firefa_main_app/features/payment/payment_dashboard_controller.dart';
import 'package:firefa_main_app/features/payment/payment_transaction_model.dart';

void main() {
  group('PaymentDashboardController', () {
    test('summarizes all transactions and completed payment revenue', () {
      final payments = PaymentController()
        ..addTransaction(const PaymentTransaction(
          transactionId: 'PAY-1',
          orderId: 'ORD-1',
          amount: 20,
          method: 'cash',
          status: 'completed',
        ))
        ..addTransaction(const PaymentTransaction(
          transactionId: 'PAY-2',
          orderId: 'ORD-2',
          amount: 15,
          method: 'card',
          status: 'completed',
        ))
        ..addTransaction(const PaymentTransaction(
          transactionId: 'PAY-3',
          orderId: 'ORD-3',
          amount: 99,
          method: 'cash',
          status: 'pending',
        ));

      final summary = PaymentDashboardController(payments).getSummary();

      expect(summary.totalTransactions, 3);
      expect(summary.successfulPayments, 2);
      expect(summary.totalRevenue, 35);
    });

    test('returns zero totals when no transactions exist', () {
      final summary =
          PaymentDashboardController(PaymentController()).getSummary();

      expect(summary.totalTransactions, 0);
      expect(summary.successfulPayments, 0);
      expect(summary.totalRevenue, 0);
    });
  });
}
