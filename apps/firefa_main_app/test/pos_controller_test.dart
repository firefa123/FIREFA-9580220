import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/pos_controller.dart';

void main() {
  group('PosController cart quantities', () {
    test('adding an existing product increments its quantity and total', () {
      final controller = PosController();

      controller.addItem('Coffee', 15000);
      controller.addItem('Coffee', 15000);

      expect(controller.cart, hasLength(1));
      expect(controller.cart.single.quantity, 2);
      expect(controller.cart.single.subtotal, 30000);
      expect(controller.total, 30000);
    });

    test('decrement reduces quantity and recalculates total', () {
      final controller = PosController();

      controller.addItem('Tea', 10000);
      controller.addItem('Tea', 10000);
      controller.decreaseItem('Tea');

      expect(controller.cart.single.quantity, 1);
      expect(controller.total, 10000);
    });

    test('decrementing the last unit removes the cart line', () {
      final controller = PosController();
      controller.addItem('Burger', 25000);

      controller.decreaseItem('Burger');

      expect(controller.cart, isEmpty);
      expect(controller.total, 0);
    });

    test('decrementing an unknown product leaves the cart unchanged', () {
      final controller = PosController();
      controller.addItem('Coffee', 15000);

      controller.decreaseItem('Tea');

      expect(controller.cart, hasLength(1));
      expect(controller.total, 15000);
    });
  });
}
