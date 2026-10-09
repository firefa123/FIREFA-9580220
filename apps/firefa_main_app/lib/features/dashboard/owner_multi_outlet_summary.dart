class OwnerMultiOutletSummary {
  final int totalOutlets;
  final int totalOrders;
  final int preparingOrders;
  final int readyOrders;
  final int offlineOrders;

  const OwnerMultiOutletSummary({
    required this.totalOutlets,
    required this.totalOrders,
    required this.preparingOrders,
    required this.readyOrders,
    required this.offlineOrders,
  });
}
