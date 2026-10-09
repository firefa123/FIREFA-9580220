class DashboardOrderOverview {
  final int totalOrders;
  final int preparingOrders;
  final int readyOrders;
  final int offlineQueue;

  const DashboardOrderOverview({
    required this.totalOrders,
    required this.preparingOrders,
    required this.readyOrders,
    required this.offlineQueue,
  });
}
