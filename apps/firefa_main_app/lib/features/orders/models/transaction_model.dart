enum TransactionStatus {
  pending,
  awaitingPayment,
  paid,
  cancelled,
  completed,
}

enum SyncStatus {
  pending,
  synced,
  failed,
}

/// Immutable checkout-time copy of a cart line. Product catalogue changes must
/// not alter the price or quantity recorded on an existing transaction.
class TransactionLineItem {
  final String id;
  final String name;
  final int unitPrice;
  final int quantity;

  const TransactionLineItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  int get subtotal => unitPrice * quantity;

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  static TransactionLineItem fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final unitPrice = json['unitPrice'];
    final quantity = json['quantity'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        unitPrice is! int ||
        unitPrice < 0 ||
        quantity is! int ||
        quantity <= 0 ||
        unitPrice != 0 && quantity > 999999999 ~/ unitPrice) {
      throw const FormatException('Detail item transaksi tidak valid.');
    }
    return TransactionLineItem(
      id: id,
      name: name,
      unitPrice: unitPrice,
      quantity: quantity,
    );
  }
}

class TransactionModel {
  final String id;
  final DateTime createdAt;
  final double totalAmount;
  final TransactionStatus status;
  final SyncStatus syncStatus;
  final List<String> itemIds;
  final List<TransactionLineItem> itemDetails;

  TransactionModel({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
    this.syncStatus = SyncStatus.pending,
    required List<String> itemIds,
    List<TransactionLineItem> itemDetails = const [],
  })  : itemIds = List.unmodifiable(itemIds),
        itemDetails = List.unmodifiable(itemDetails);

  TransactionModel copyWith({
    String? id,
    DateTime? createdAt,
    double? totalAmount,
    TransactionStatus? status,
    SyncStatus? syncStatus,
    List<String>? itemIds,
    List<TransactionLineItem>? itemDetails,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      itemIds: itemIds ?? this.itemIds,
      itemDetails: itemDetails ?? this.itemDetails,
    );
  }
}
