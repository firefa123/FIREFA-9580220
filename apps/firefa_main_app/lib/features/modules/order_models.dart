enum FirefaOrderStatus {
  draft,
  confirmed,
  preparing,
  ready,
  served,
  completed,
  cancelled,
}

enum FirefaPaymentStatus { unpaid, paid, refunded }

enum FirefaPaymentVerificationStatus { notReported, reported, verified, failed }

enum FirefaRefundVerificationStatus { reported, verified, failed }

extension FirefaPaymentVerificationStatusDetails on FirefaPaymentVerificationStatus {
  String get label => switch (this) {
    FirefaPaymentVerificationStatus.notReported => "Belum dilaporkan",
    FirefaPaymentVerificationStatus.reported => "Dilaporkan • belum diverifikasi",
    FirefaPaymentVerificationStatus.verified => "Terverifikasi",
    FirefaPaymentVerificationStatus.failed => "Gagal diverifikasi",
  };
}

extension FirefaRefundVerificationStatusDetails on FirefaRefundVerificationStatus {
  String get label => switch (this) {
    FirefaRefundVerificationStatus.reported => "Dilaporkan • belum diverifikasi",
    FirefaRefundVerificationStatus.verified => "Terverifikasi",
    FirefaRefundVerificationStatus.failed => "Gagal diverifikasi",
  };
}

class FirefaRefundRecord {
  final int amount;
  final String method;
  final String reason;
  final DateTime createdAt;
  final FirefaRefundVerificationStatus verificationStatus;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  const FirefaRefundRecord({
    required this.amount,
    required this.method,
    required this.reason,
    required this.createdAt,
    this.verificationStatus = FirefaRefundVerificationStatus.reported,
    this.verifiedAt,
    this.verifiedBy,
  });

  FirefaRefundRecord copyWith({
    FirefaRefundVerificationStatus? verificationStatus,
    DateTime? verifiedAt,
    String? verifiedBy,
  }) => FirefaRefundRecord(
    amount: amount,
    method: method,
    reason: reason,
    createdAt: createdAt,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    verifiedBy: verifiedBy ?? this.verifiedBy,
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'method': method,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'verificationStatus': verificationStatus.name,
    'verifiedAt': verifiedAt?.toIso8601String(),
    'verifiedBy': verifiedBy,
  };

  factory FirefaRefundRecord.fromJson(Map<String, dynamic> json) => FirefaRefundRecord(
    amount: json['amount'] as int,
    method: json['method'] as String,
    reason: json['reason'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    verificationStatus: FirefaRefundVerificationStatus.values.byName(
      json['verificationStatus'] as String? ?? FirefaRefundVerificationStatus.reported.name,
    ),
    verifiedAt: json['verifiedAt'] == null ? null : DateTime.parse(json['verifiedAt'] as String),
    verifiedBy: json['verifiedBy'] as String?,
  );
}

extension FirefaOrderStatusDetails on FirefaOrderStatus {
  String get label {
    switch (this) {
      case FirefaOrderStatus.draft:
        return 'Draft';
      case FirefaOrderStatus.confirmed:
        return 'Confirmed';
      case FirefaOrderStatus.preparing:
        return 'Preparing';
      case FirefaOrderStatus.ready:
        return 'Ready';
      case FirefaOrderStatus.served:
        return 'Served';
      case FirefaOrderStatus.completed:
        return 'Completed';
      case FirefaOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  FirefaOrderStatus? get next {
    switch (this) {
      case FirefaOrderStatus.draft:
        return FirefaOrderStatus.confirmed;
      case FirefaOrderStatus.confirmed:
        return FirefaOrderStatus.preparing;
      case FirefaOrderStatus.preparing:
        return FirefaOrderStatus.ready;
      case FirefaOrderStatus.ready:
        return FirefaOrderStatus.served;
      case FirefaOrderStatus.served:
        return FirefaOrderStatus.completed;
      case FirefaOrderStatus.completed:
      case FirefaOrderStatus.cancelled:
        return null;
    }
  }

  bool get canCancel =>
      this == FirefaOrderStatus.draft || this == FirefaOrderStatus.confirmed;
}

class FirefaOrderItem {
  final String productName;
  final int quantity;
  final int unitPrice;
  final String details;
  final String? productId;

  const FirefaOrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.details = '',
    this.productId,
  });

  int get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'details': details,
        if (productId != null) 'productId': productId,
      };

  factory FirefaOrderItem.fromJson(Map<String, dynamic> json) {
    return FirefaOrderItem(
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: json['unitPrice'] as int,
      details: json['details'] as String? ?? '',
      productId: json['productId'] as String?,
    );
  }
}

class FirefaOrder {
  final String id;
  final String outletId;
  final String orderType;
  final String? tableId;
  String? customerId;
  String? customerName;
  final DateTime createdAt;
  DateTime? completedAt;
  DateTime? paidAt;
  String? paymentMethod;
  int cashPaidAmount;
  FirefaPaymentVerificationStatus paymentVerificationStatus;
  DateTime? paymentVerifiedAt;
  String? paymentVerifiedBy;
  DateTime? refundedAt;
  String? refundMethod;
  String? refundReason;
  int cashRefundAmount;
  int refundAmount;
  final List<FirefaRefundRecord> refundRecords;
  final List<FirefaOrderItem> items;
  final int subtotal;
  final int discount;
  final int tax;
  final int service;
  final int total;

  FirefaOrderStatus status;
  FirefaPaymentStatus paymentStatus;

  FirefaOrder({
    required this.id,
    required this.outletId,
    required this.orderType,
    required this.tableId,
    this.customerId,
    this.customerName,
    required this.createdAt,
    this.completedAt,
    this.paidAt,
    this.paymentMethod,
    this.cashPaidAmount = 0,
    this.paymentVerificationStatus = FirefaPaymentVerificationStatus.notReported,
    this.paymentVerifiedAt,
    this.paymentVerifiedBy,
    this.refundedAt,
    this.refundMethod,
    this.refundReason,
    this.cashRefundAmount = 0,
    this.refundAmount = 0,
    List<FirefaRefundRecord> refundRecords = const [],
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.service,
    required this.total,
    this.status = FirefaOrderStatus.confirmed,
    this.paymentStatus = FirefaPaymentStatus.unpaid,
  }) : refundRecords = List<FirefaRefundRecord>.from(refundRecords);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get refundableAmount => (total - refundAmount).clamp(0, total);
  bool get hasPartialRefund => refundAmount > 0 && refundAmount < total;

  bool get canComplete =>
      status == FirefaOrderStatus.served &&
      paymentStatus == FirefaPaymentStatus.paid;

  bool advanceStatus() {
    final nextStatus = status.next;
    if (nextStatus == null) return false;

    if (nextStatus == FirefaOrderStatus.completed &&
        paymentStatus != FirefaPaymentStatus.paid) {
      return false;
    }

    status = nextStatus;
    if (nextStatus == FirefaOrderStatus.completed) {
      // Record an actual completion time for operational reporting.
      // Existing persisted orders remain compatible when this field is absent.
      completedAt = DateTime.now();
    }
    return true;
  }


  bool cancel() {
    if (!status.canCancel || paymentStatus != FirefaPaymentStatus.unpaid) {
      return false;
    }

    status = FirefaOrderStatus.cancelled;
    return true;
  }

  bool markPaid({
    String? method,
    int cashAmount = 0,
    DateTime? paymentTime,
  }) {
    if (status == FirefaOrderStatus.draft ||
        status == FirefaOrderStatus.cancelled ||
        paymentStatus != FirefaPaymentStatus.unpaid) {
      return false;
    }
    if (cashAmount < 0 || cashAmount > total) return false;

    paymentStatus = FirefaPaymentStatus.paid;
    paymentVerificationStatus = FirefaPaymentVerificationStatus.reported;
    paymentVerifiedAt = null;
    paymentVerifiedBy = null;
    paymentMethod = method;
    cashPaidAmount = cashAmount;
    paidAt = paymentTime ?? DateTime.now();
    return true;
  }

  bool markBon() {
    if (status == FirefaOrderStatus.draft || status == FirefaOrderStatus.cancelled || paymentStatus != FirefaPaymentStatus.unpaid) return false;
    paymentMethod = 'BON';
    paymentVerificationStatus = FirefaPaymentVerificationStatus.notReported;
    paymentVerifiedAt = null;
    paymentVerifiedBy = null;
    paidAt = null;
    cashPaidAmount = 0;
    return true;
  }

  bool markPaymentVerified({String? verifiedBy, DateTime? verifiedAt}) {
    if (paymentVerificationStatus == FirefaPaymentVerificationStatus.verified) return true;
    if (paymentStatus != FirefaPaymentStatus.paid ||
        paymentVerificationStatus != FirefaPaymentVerificationStatus.reported) {
      return false;
    }
    paymentVerificationStatus = FirefaPaymentVerificationStatus.verified;
    paymentVerifiedAt = verifiedAt ?? DateTime.now();
    paymentVerifiedBy = verifiedBy;
    return true;
  }

  bool markPaymentFailed() {
    if (paymentVerificationStatus != FirefaPaymentVerificationStatus.reported ||
        refundRecords.isNotEmpty) {
      return false;
    }
    paymentVerificationStatus = FirefaPaymentVerificationStatus.failed;
    paymentStatus = FirefaPaymentStatus.unpaid;
    paymentMethod = null;
    cashPaidAmount = 0;
    paidAt = null;
    return true;
  }

  bool markRefundVerified(int index, {String? verifiedBy, DateTime? verifiedAt}) {
    if (paymentVerificationStatus != FirefaPaymentVerificationStatus.verified ||
        index < 0 || index >= refundRecords.length) {
      return false;
    }
    final record = refundRecords[index];
    if (record.verificationStatus == FirefaRefundVerificationStatus.verified) {
      return true;
    }
    if (record.verificationStatus != FirefaRefundVerificationStatus.reported) {
      return false;
    }
    refundRecords[index] = record.copyWith(
      verificationStatus: FirefaRefundVerificationStatus.verified,
      verifiedAt: verifiedAt ?? DateTime.now(),
      verifiedBy: verifiedBy,
    );
    final verifiedRefundTotal = refundRecords
      .where((entry) => entry.verificationStatus == FirefaRefundVerificationStatus.verified)
      .fold<int>(0, (sum, entry) => sum + entry.amount);
    if (verifiedRefundTotal >= total && total > 0) {
      paymentStatus = FirefaPaymentStatus.refunded;
    }
    return true;
  }

  bool markRefunded({required String method, required String reason, int? amount, DateTime? refundTime}) {
    final refundValue = amount ?? refundableAmount;
    final normalizedMethod = method.trim();
    final normalizedReason = reason.trim();
    if (paymentStatus != FirefaPaymentStatus.paid || normalizedMethod.isEmpty || normalizedReason.isEmpty || refundValue <= 0 || refundValue > refundableAmount) return false;
    final timestamp = refundTime ?? DateTime.now();
    refundRecords.add(FirefaRefundRecord(amount: refundValue, method: normalizedMethod, reason: normalizedReason, createdAt: timestamp));
    refundAmount += refundValue;
    if (normalizedMethod.toLowerCase() == 'cash') cashRefundAmount += refundValue;
    refundedAt = timestamp;
    refundMethod = normalizedMethod;
    refundReason = normalizedReason;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'outletId': outletId,
        'orderType': orderType,
        'tableId': tableId,
        'customerId': customerId,
        'customerName': customerName,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'paymentMethod': paymentMethod,
        'cashPaidAmount': cashPaidAmount,
        'paymentVerificationStatus': paymentVerificationStatus.name,
        'paymentVerifiedAt': paymentVerifiedAt?.toIso8601String(),
        'paymentVerifiedBy': paymentVerifiedBy,
        'refundedAt': refundedAt?.toIso8601String(),
        'refundMethod': refundMethod,
        'refundReason': refundReason,
        'cashRefundAmount': cashRefundAmount,
        'refundAmount': refundAmount,
        'refundRecords': refundRecords.map((record) => record.toJson()).toList(),
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'service': service,
        'total': total,
        'status': status.name,
        'paymentStatus': paymentStatus.name,
      };

  factory FirefaOrder.fromJson(Map<String, dynamic> json) {
    final savedPaymentStatus = FirefaPaymentStatus.values.byName(json['paymentStatus'] as String);
    final refundRecords = json['refundRecords'] is List
        ? (json['refundRecords'] as List).map((entry) => FirefaRefundRecord.fromJson(Map<String, dynamic>.from(entry as Map))).toList()
        : (savedPaymentStatus == FirefaPaymentStatus.refunded ? [FirefaRefundRecord(amount: json['total'] as int? ?? 0, method: json['refundMethod'] as String? ?? 'Legacy', reason: json['refundReason'] as String? ?? 'Legacy refund', createdAt: json['refundedAt'] == null ? DateTime.parse(json['createdAt'] as String) : DateTime.parse(json['refundedAt'] as String))] : <FirefaRefundRecord>[]);
    final verifiedRefundTotal = refundRecords
        .where((record) => record.verificationStatus == FirefaRefundVerificationStatus.verified)
        .fold<int>(0, (sum, record) => sum + record.amount);
    final hasVerifiedFullRefund = (json['total'] as int? ?? 0) > 0 &&
        verifiedRefundTotal >= (json['total'] as int? ?? 0);
    final savedVerification = json['paymentVerificationStatus'] as String?;
    final effectiveVerification = savedVerification == null
        ? (savedPaymentStatus == FirefaPaymentStatus.paid || savedPaymentStatus == FirefaPaymentStatus.refunded ? FirefaPaymentVerificationStatus.reported : FirefaPaymentVerificationStatus.notReported)
        : FirefaPaymentVerificationStatus.values.byName(savedVerification);
    final effectivePaymentStatus = savedPaymentStatus == FirefaPaymentStatus.refunded &&
        (!hasVerifiedFullRefund || effectiveVerification != FirefaPaymentVerificationStatus.verified)
        ? FirefaPaymentStatus.paid
        : savedPaymentStatus;
    final order = FirefaOrder(
      id: json['id'] as String,
      outletId: json['outletId'] as String,
      orderType: json['orderType'] as String,
      tableId: json['tableId'] as String?,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      paymentMethod: json['paymentMethod'] as String?,
      cashPaidAmount: json['cashPaidAmount'] as int? ?? 0,
      paymentVerificationStatus: effectiveVerification,
      paymentVerifiedAt: json['paymentVerifiedAt'] == null ? null : DateTime.parse(json['paymentVerifiedAt'] as String),
      paymentVerifiedBy: json['paymentVerifiedBy'] as String?,
      refundedAt: json['refundedAt'] == null
          ? null
          : DateTime.parse(json['refundedAt'] as String),
      refundMethod: json['refundMethod'] as String?,
      refundReason: json['refundReason'] as String?,
      cashRefundAmount: json['cashRefundAmount'] as int? ?? 0,
      refundAmount: json['refundAmount'] as int? ?? (json['paymentStatus'] == FirefaPaymentStatus.refunded.name ? (json['total'] as int? ?? 0) : 0),
      refundRecords: refundRecords,
      items: List.unmodifiable(
        (json['items'] as List).map(
          (item) =>
              FirefaOrderItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      subtotal: json['subtotal'] as int,
      discount: json['discount'] as int,
      tax: json['tax'] as int,
      service: json['service'] as int,
      total: json['total'] as int,
      status: FirefaOrderStatus.values.byName(json['status'] as String),
      paymentStatus: effectivePaymentStatus,
    );
    return order;
  }
}
