class StaffOrderSyncStatus {
  final int pendingOrders;
  final bool online;

  const StaffOrderSyncStatus({
    required this.pendingOrders,
    required this.online,
  });

  String get label {
    if (!online) {
      return '$pendingOrders pesanan menunggu sinkronisasi';
    }

    return 'Semua pesanan tersinkronisasi';
  }
}
