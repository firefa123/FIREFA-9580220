import 'cart_item_model.dart';
import 'cart_repository.dart';

class CartStore {
  final CartRepository repository;

  CartStore({required this.repository});

  List<CartItem> items = [];

  Future<void> load() async {
    items = await repository.loadCart();
  }

  Future<void> add(CartItem item) async {
    final index = items.indexWhere((e) => e.productId == item.productId);

    if (index >= 0) {
      final old = items[index];
      items[index] = CartItem(
        productId: old.productId,
        name: old.name,
        qty: old.qty + item.qty,
        price: old.price,
      );
    } else {
      items.add(item);
    }

    await repository.saveCart(items);
  }

  Future<void> remove(String productId) async {
    items.removeWhere((e) => e.productId == productId);
    await repository.saveCart(items);
  }

  Future<void> clear() async {
    items.clear();
    await repository.clear();
  }

  double get total {
    return items.fold(0, (sum, item) => sum + item.subtotal);
  }
}
