class DashboardLiveSummary {
  final int kitchenOrders;
  final int offlineQueue;

  const DashboardLiveSummary({
    required this.kitchenOrders,
    required this.offlineQueue,
  });

  factory DashboardLiveSummary.fromMap(
    Map<String, int> data,
  ) {
    return DashboardLiveSummary(
      kitchenOrders: data['kitchenOrders'] ?? 0,
      offlineQueue: data['offlineQueue'] ?? 0,
    );
  }
}
