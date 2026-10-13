import 'inventory_store.dart';
import 'recipe_ingredient_model.dart';

class OrderMenuQuantity {
  final String menuId;
  final double quantity;
  const OrderMenuQuantity({required this.menuId, required this.quantity});
}

/// Converts menu quantities and recipes into an atomic stock-consumption request.
class OrderInventoryService {
  final InventoryStore inventory;
  const OrderInventoryService({required this.inventory});

  Future<bool> consumeOrder({
    required String orderId,
    required String outletId,
    required List<OrderMenuQuantity> menuLines,
    required List<RecipeIngredient> recipes,
  }) async {
    if (menuLines.isEmpty) throw ArgumentError('Pesanan tidak memiliki item menu.');
    final requirements = <String, double>{};
    for (final line in menuLines) {
      if (line.menuId.trim().isEmpty || !line.quantity.isFinite || line.quantity <= 0) {
        throw ArgumentError('Kuantitas menu tidak valid.');
      }
      final matching = recipes.where((recipe) => recipe.menuId == line.menuId).toList();
      if (matching.isEmpty) {
        throw StateError('Resep menu ${line.menuId} belum tersedia.');
      }
      for (final recipe in matching) {
        if (!recipe.quantity.isFinite || recipe.quantity <= 0 || recipe.ingredientId.trim().isEmpty) {
          throw StateError('Resep mengandung kuantitas bahan yang tidak valid.');
        }
        requirements[recipe.ingredientId] =
            (requirements[recipe.ingredientId] ?? 0) + recipe.quantity * line.quantity;
      }
    }
    return inventory.consumeOrderIngredients(
      orderId: orderId,
      outletId: outletId,
      ingredientQuantities: requirements,
    );
  }
}
