class MenuStockAvailabilityController {
  bool isAvailable({
    required bool hasRecipe,
    required bool hasStock,
  }) {
    return hasRecipe && hasStock;
  }

  String status({
    required bool available,
  }) {
    return available ? 'available' : 'unavailable';
  }
}
