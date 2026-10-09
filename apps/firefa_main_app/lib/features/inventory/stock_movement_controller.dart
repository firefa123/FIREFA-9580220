import 'stock_movement_model.dart';

class StockMovementController {
  final List<StockMovement> movements = [];

  void addMovement(StockMovement movement) {
    movements.add(movement);
  }

  List<StockMovement> get history => movements;
}
