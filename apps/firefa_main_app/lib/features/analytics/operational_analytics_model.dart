class OperationalAnalyticsModel {
  final int totalOrders;
  final int completedOrders;
  final double averageCompletionMinutes;

  const OperationalAnalyticsModel({
    required this.totalOrders,
    required this.completedOrders,
    required this.averageCompletionMinutes,
  });
}
