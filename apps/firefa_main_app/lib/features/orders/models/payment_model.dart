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

enum PaymentVerificationStatus {
  notReported,
  reported,
  verified,
  failed,
}

extension PaymentVerificationStatusDetails on PaymentVerificationStatus {
  String get label => switch (this) {
    PaymentVerificationStatus.notReported => 'Belum dilaporkan',
    PaymentVerificationStatus.reported => 'Dilaporkan • belum diverifikasi',
    PaymentVerificationStatus.verified => 'Terverifikasi',
    PaymentVerificationStatus.failed => 'Gagal diverifikasi',
  };
}

class PaymentModel {
  final String id;
  final String transactionId;
  final PaymentMethod method;
  final PaymentStatus status;
  final PaymentVerificationStatus verificationStatus;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final double amount;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.transactionId,
    required this.method,
    required this.status,
    this.verificationStatus = PaymentVerificationStatus.notReported,
    this.verifiedAt,
    this.verifiedBy,
    required this.amount,
    required this.createdAt,
  });

  PaymentModel copyWith({
    String? id,
    String? transactionId,
    PaymentMethod? method,
    PaymentStatus? status,
    PaymentVerificationStatus? verificationStatus,
    DateTime? verifiedAt,
    String? verifiedBy,
    double? amount,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      method: method ?? this.method,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
