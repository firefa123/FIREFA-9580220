import 'multi_outlet_settlement_model.dart';

class MultiOutletSettlementController {
  final List<MultiOutletSettlement> settlements = [];

  void addSettlement(MultiOutletSettlement settlement) {
    settlements.add(settlement);
  }

  double get totalRevenue {
    return settlements.fold(
      0,
      (sum, item) => sum + item.revenue,
    );
  }
}
