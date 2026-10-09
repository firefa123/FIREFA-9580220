import '../../core/storage/local_storage.dart';
import 'cart_item_model.dart';

class CartRepository {
  static const String key = 'firefa_cart';

  Future<void> saveCart(List<CartItem> items) async {
    await LocalStorage.save(
      key,
      items.map((e) => e.toJson()).toList(),
    );
  }

  Future<List<CartItem>> loadCart() async {
    final data = await LocalStorage.read(key);

    if (data == null) return [];

    return (data as List)
        .map((e) => CartItem.fromJson(e))
        .toList();
  }

  Future<void> clear() async {
    await LocalStorage.remove(key);
  }
}
