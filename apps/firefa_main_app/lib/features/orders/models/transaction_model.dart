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

class TransactionModel {
  final String id;
  final DateTime createdAt;
  final double totalAmount;
  final TransactionStatus status;
  final SyncStatus syncStatus;
  final List<String> itemIds;

  const TransactionModel({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
    this.syncStatus = SyncStatus.pending,
    required this.itemIds,
  });

  TransactionModel copyWith({
    String? id,
    DateTime? createdAt,
    double? totalAmount,
    TransactionStatus? status,
    SyncStatus? syncStatus,
    List<String>? itemIds,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      itemIds: itemIds ?? this.itemIds,
    );
  }
}
