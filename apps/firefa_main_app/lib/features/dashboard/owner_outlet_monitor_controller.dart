import 'owner_multi_outlet_summary.dart';

class OwnerOutletMonitorController {
  OwnerMultiOutletSummary summary = const OwnerMultiOutletSummary(
    totalOutlets: 0,
    totalOrders: 0,
    preparingOrders: 0,
    readyOrders: 0,
    offlineOrders: 0,
  );

  void update(OwnerMultiOutletSummary value) {
    summary = value;
  }
}
