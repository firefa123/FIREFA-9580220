import 'customer_checkout_model.dart';

class CustomerCheckoutController {
  CustomerCheckoutModel buildCheckout({
    required int itemCount,
    required double subtotal,
  }) {
    return CustomerCheckoutModel(
      itemCount: itemCount,
      subtotal: subtotal,
    );
  }
}
