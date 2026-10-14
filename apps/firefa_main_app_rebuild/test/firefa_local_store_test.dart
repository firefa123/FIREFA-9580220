import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late FirefaLocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = FirefaLocalStore(preferences: preferences);
    await store.initialize();
  });

  tearDown(() {
    store.dispose();
  });

  test('checkout creates an order and deducts menu stock', () async {
    final product = store.products.firstWhere((item) => item.id == 'P01');
    final startingStock = product.stock;

    final order = await store.checkout(
      quantities: {'P01': 2},
      type: 'Dine In',
      table: 'T1',
    );

    expect(order.lines.single.quantity, 2);
    expect(order.total, product.price * 2);
    expect(product.stock, startingStock - 2);
    expect(store.orders, contains(order));
    expect(store.isTableOccupied('T1'), isTrue);
  });

  test('cancelling an order restores stock exactly once', () async {
    final product = store.products.firstWhere((item) => item.id == 'P02');
    final startingStock = product.stock;
    final order = await store.checkout(
      quantities: {'P02': 3},
      type: 'Take Away',
    );

    expect(product.stock, startingStock - 3);
    await store.cancelOrder(order);
    expect(product.stock, startingStock);
    await store.cancelOrder(order);
    expect(product.stock, startingStock);
    expect(order.status, 'Dibatalkan');
  });

  test('checkout data and stock survive store reinitialization', () async {
    await store.checkout(quantities: {'P03': 1}, type: 'Take Away');

    final restored = FirefaLocalStore(preferences: preferences);
    await restored.initialize();

    expect(restored.orders, hasLength(1));
    expect(restored.orders.single.lines.single.name, 'Americano');
    expect(restored.products.firstWhere((item) => item.id == 'P03').stock, 44);
    restored.dispose();
  });

  test('checkout rejects an empty cart without creating an order', () async {
    await expectLater(
      store.checkout(quantities: {}, type: 'Take Away'),
      throwsStateError,
    );
    expect(store.orders, isEmpty);
  });

  test('checkout rejects quantities beyond available stock', () async {
    final product = store.products.first;
    final startingStock = product.stock;

    await expectLater(
      store.checkout(
        quantities: {product.id: startingStock + 1},
        type: 'Take Away',
      ),
      throwsStateError,
    );
    expect(product.stock, startingStock);
    expect(store.orders, isEmpty);
  });
}
