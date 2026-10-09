class CartItem {
  final String productId;
  final String name;
  final int qty;
  final double price;

  const CartItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
  });

  double get subtotal => qty * price;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'qty': qty,
      'price': price,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'],
      name: json['name'],
      qty: json['qty'],
      price: json['price'].toDouble(),
    );
  }
}
