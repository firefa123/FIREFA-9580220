class OrderStockIntegration {
  bool canFulfillOrder({
    required int availableStock,
    required int requiredStock,
  }) {
    return availableStock >= requiredStock;
  }

  int calculateRemainingStock({
    required int availableStock,
    required int usedStock,
  }) {
    final result = availableStock - usedStock;
    return result < 0 ? 0 : result;
  }
}
