import '../models/cart_item_model.dart';

class PosController {
  final List<CartItemModel> cart = [];

  void addItem(String name, int price) {
    final existing = cart.where((item) => item.name == name).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      cart.add(
        CartItemModel(
          id: _generateCartItemId(name),
          name: name,
          price: price,
        ),
      );
    }
  }

  void removeItem(String name) {
    cart.removeWhere((item) => item.name == name);
  }

  void clearCart() {
    cart.clear();
  }

  int get total => cart.fold(0, (sum, item) => sum + item.subtotal);

  String _generateCartItemId(String name) {
    final normalizedName = name.toLowerCase().replaceAll(' ', '-');
    return '$normalizedName-${DateTime.now().microsecondsSinceEpoch}';
  }
}
