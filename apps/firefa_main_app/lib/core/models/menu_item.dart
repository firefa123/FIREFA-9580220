class ProductVariant {
  final String id;
  final String name;
  final int price;
  final bool available;
  final String? sku;
  final String? barcode;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    this.available = true,
    this.sku,
    this.barcode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'available': available,
        'sku': sku,
        'barcode': barcode,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> json) =>
      ProductVariant(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toInt(),
        available: json['available'] as bool? ?? true,
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
      );
}

class MenuItem {
  final String id;
  final String name;
  final String category;
  final int price;
  final bool available;
  final String? outletId;
  final String? sku;
  final String? barcode;
  final List<ProductVariant> variants;

  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.available,
    this.outletId,
    this.sku,
    this.barcode,
    this.variants = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'available': available,
        'outletId': outletId,
        'sku': sku,
        'barcode': barcode,
        'variants': variants.map((variant) => variant.toJson()).toList(),
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'Lainnya',
        price: (json['price'] as num).toInt(),
        available: json['available'] as bool? ?? true,
        outletId: json['outletId'] as String?,
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        variants: (json['variants'] as List<dynamic>? ?? const [])
            .map((item) => ProductVariant.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
      );
}
