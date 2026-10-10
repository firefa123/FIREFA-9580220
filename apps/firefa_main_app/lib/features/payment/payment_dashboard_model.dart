class PaymentDashboardModel {
  final int totalTransactions;
  final double totalRevenue;
  final int successfulPayments;

  const PaymentDashboardModel({
    required this.totalTransactions,
    required this.totalRevenue,
    required this.successfulPayments,
  });
}
