class StockAlertController {
  bool isLowStock({
    required int stock,
    required int minimum,
  }) {
    return stock <= minimum;
  }
}
