import 'package:flutter/foundation.dart';

/// Bridge between POS transactions and inventory hybrid workflow.
/// Keeps POS flow independent while allowing stock movement creation.
class FirefaPosInventoryBridge extends ChangeNotifier {
  final List<FirefaStockMovementRequest> _pendingMovements = [];

  List<FirefaStockMovementRequest> get pendingMovements =>
      List.unmodifiable(_pendingMovements);

  void createStockMovement({
    required String orderId,
    required String itemId,
    required int quantity,
  }) {
    _pendingMovements.add(
      FirefaStockMovementRequest(
        orderId: orderId,
        itemId: itemId,
        quantity: quantity,
        status: 'QUEUED',
      ),
    );
    notifyListeners();
  }
}

class FirefaStockMovementRequest {
  final String orderId;
  final String itemId;
  final int quantity;
  final String status;

  const FirefaStockMovementRequest({
    required this.orderId,
    required this.itemId,
    required this.quantity,
    required this.status,
  });
}
