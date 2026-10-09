import 'sales_report_model.dart';

class SalesReportController {
  SalesReportModel generate({
    required double sales,
    required int transactions,
    required int successful,
  }) {
    return SalesReportModel(
      totalSales: sales,
      totalTransactions: transactions,
      successfulTransactions: successful,
    );
  }
}
