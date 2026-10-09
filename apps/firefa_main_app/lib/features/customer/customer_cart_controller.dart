class CustomerCartController {
  int itemCount = 0;
  double subtotal = 0;

  void updateCart({required int count, required double amount}) {
    itemCount = count;
    subtotal = amount;
  }
}
