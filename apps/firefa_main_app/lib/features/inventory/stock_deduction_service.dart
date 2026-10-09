class StockDeductionService {
  int deduct({
    required int currentStock,
    required int usage,
  }) {
    final remaining = currentStock - usage;
    return remaining < 0 ? 0 : remaining;
  }
}
