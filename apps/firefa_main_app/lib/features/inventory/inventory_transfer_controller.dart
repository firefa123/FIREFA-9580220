import 'inventory_outlet_stock_model.dart';

/// In-memory inventory outlet stock transfer records.
///
/// The current model represents the outlet/item/quantity entry only. Source
/// outlet, destination outlet and durable stock mutation require a richer
/// transfer model and repository integration.
class InventoryTransferController {
  final List<InventoryOutletStock> _transfers = [];

  List<InventoryOutletStock> get transfers => List.unmodifiable(_transfers);
  List<InventoryOutletStock> get history => transfers;

  void transfer(InventoryOutletStock stock) {
    final outletId = stock.outletId.trim();
    final itemId = stock.itemId.trim();
    if (outletId.isEmpty) {
      throw ArgumentError.value(stock.outletId, 'stock.outletId', 'Outlet ID cannot be empty.');
    }
    if (itemId.isEmpty) {
      throw ArgumentError.value(stock.itemId, 'stock.itemId', 'Item ID cannot be empty.');
    }
    if (!stock.quantity.isFinite || stock.quantity <= 0) {
      throw ArgumentError.value(stock.quantity, 'stock.quantity', 'Quantity must be finite and greater than zero.');
    }

    _transfers.add(InventoryOutletStock(
      outletId: outletId,
      itemId: itemId,
      quantity: stock.quantity,
    ));
  }

  List<InventoryOutletStock> historyForOutlet(String outletId) {
    final normalized = outletId.trim();
    return List.unmodifiable(
      _transfers.where((entry) => entry.outletId == normalized),
    );
  }

  List<InventoryOutletStock> historyForItem(String itemId) {
    final normalized = itemId.trim();
    return List.unmodifiable(
      _transfers.where((entry) => entry.itemId == normalized),
    );
  }

  double totalQuantityForOutlet(String outletId) {
    return historyForOutlet(outletId).fold<double>(
      0,
      (total, entry) => total + entry.quantity,
    );
  }
}
