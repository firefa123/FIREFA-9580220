class TransactionModel {
  final String id;
  final DateTime createdAt;
  final double totalAmount;
  final String status;
  final List<String> itemIds;

  const TransactionModel({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
    required this.itemIds,
  });

  TransactionModel copyWith({
    String? id,
    DateTime? createdAt,
    double? totalAmount,
    String? status,
    List<String>? itemIds,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      itemIds: itemIds ?? this.itemIds,
    );
  }
}
