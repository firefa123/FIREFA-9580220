import 'package:flutter/foundation.dart';

class CustomerCartItem {
  final String productId;
  final String name;
  final int price;
  int quantity;

  CustomerCartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  int get total => price * quantity;
}

class FirefaCustomerCartStore extends ChangeNotifier {
  FirefaCustomerCartStore._();

  static final instance = FirefaCustomerCartStore._();

  final List<CustomerCartItem> _items = [];

  List<CustomerCartItem> get items => List.unmodifiable(_items);

  int get total => _items.fold(0, (sum, item) => sum + item.total);

  void add(CustomerCartItem item) {
    final index = _items.indexWhere((e) => e.productId == item.productId);
    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
