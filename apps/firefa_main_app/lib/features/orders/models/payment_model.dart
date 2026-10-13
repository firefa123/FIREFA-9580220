enum PaymentMethod {
  cash,
  card,
  qris,
  bankTransfer,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

class PaymentModel {
  final String id;
  final String transactionId;
  final PaymentMethod method;
  final PaymentStatus status;
  final double amount;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.transactionId,
    required this.method,
    required this.status,
    required this.amount,
    required this.createdAt,
  });

  PaymentModel copyWith({
    String? id,
    String? transactionId,
    PaymentMethod? method,
    PaymentStatus? status,
    double? amount,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      method: method ?? this.method,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
