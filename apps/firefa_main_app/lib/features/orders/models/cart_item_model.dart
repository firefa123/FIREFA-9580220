class CartItemModel {
  final String id;
  final String name;
  final int price;
  int quantity;

  CartItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  int get subtotal => price * quantity;
}
