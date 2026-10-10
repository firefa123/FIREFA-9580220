import '../models/cart_item_model.dart';

class PosController {
  final List<CartItemModel> cart = [];

  void addItem(String name, int price) {
    final existing = cart.where((item) => item.name == name).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      cart.add(CartItemModel(name: name, price: price));
    }
  }

  void removeItem(String name) {
    cart.removeWhere((item) => item.name == name);
  }

  int get total => cart.fold(0, (sum, item) => sum + item.subtotal);
}
