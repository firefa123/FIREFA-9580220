import 'inventory_outlet_stock_model.dart';

class InventoryTransferController {
  final List<InventoryOutletStock> transfers = [];

  void transfer(InventoryOutletStock stock) {
    transfers.add(stock);
  }

  List<InventoryOutletStock> get history => transfers;
}
