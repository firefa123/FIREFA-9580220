class ManagerDashboardState {
  final bool loading;
  final int totalOrders;
  final int preparing;
  final int ready;
  final int offlineQueue;

  const ManagerDashboardState({
    required this.loading,
    required this.totalOrders,
    required this.preparing,
    required this.ready,
    required this.offlineQueue,
  });

  const ManagerDashboardState.initial()
      : loading = true,
        totalOrders = 0,
        preparing = 0,
        ready = 0,
        offlineQueue = 0;
}
