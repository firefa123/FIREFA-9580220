import 'customer_order_creation_model.dart';

class CustomerOrderCreationController {
  CustomerOrderCreationModel createOrder({
    required String orderId,
    required double subtotal,
  }) {
    return CustomerOrderCreationModel(
      orderId: orderId,
      subtotal: subtotal,
      status: 'pending',
    );
  }
}
