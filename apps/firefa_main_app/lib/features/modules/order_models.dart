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
  final DateTime createdAt;
  DateTime? completedAt;
  DateTime? paidAt;
  String? paymentMethod;
  int cashPaidAmount;
  DateTime? refundedAt;
  String? refundMethod;
  String? refundReason;
  int cashRefundAmount;
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
    required this.createdAt,
    this.completedAt,
    this.paidAt,
    this.paymentMethod,
    this.cashPaidAmount = 0,
    this.refundedAt,
    this.refundMethod,
    this.refundReason,
    this.cashRefundAmount = 0,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.service,
    required this.total,
    this.status = FirefaOrderStatus.confirmed,
    this.paymentStatus = FirefaPaymentStatus.unpaid,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

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
    if (!status.canCancel || paymentStatus == FirefaPaymentStatus.paid) {
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
        paymentStatus == FirefaPaymentStatus.paid) {
      return false;
    }
    if (cashAmount < 0 || cashAmount > total) return false;

    paymentStatus = FirefaPaymentStatus.paid;
    paymentMethod = method;
    cashPaidAmount = cashAmount;
    paidAt = paymentTime ?? DateTime.now();
    return true;
  }

  bool markRefunded({
    required String method,
    required String reason,
    DateTime? refundTime,
  }) {
    if (paymentStatus != FirefaPaymentStatus.paid ||
        method.trim().isEmpty || reason.trim().isEmpty) {
      return false;
    }
    paymentStatus = FirefaPaymentStatus.refunded;
    refundedAt = refundTime ?? DateTime.now();
    refundMethod = method.trim();
    refundReason = reason.trim();
    cashRefundAmount = method.trim().toLowerCase() == 'cash' ? total : 0;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'outletId': outletId,
        'orderType': orderType,
        'tableId': tableId,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'paymentMethod': paymentMethod,
        'cashPaidAmount': cashPaidAmount,
        'refundedAt': refundedAt?.toIso8601String(),
        'refundMethod': refundMethod,
        'refundReason': refundReason,
        'cashRefundAmount': cashRefundAmount,
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
    final order = FirefaOrder(
      id: json['id'] as String,
      outletId: json['outletId'] as String,
      orderType: json['orderType'] as String,
      tableId: json['tableId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      paymentMethod: json['paymentMethod'] as String?,
      cashPaidAmount: json['cashPaidAmount'] as int? ?? 0,
      refundedAt: json['refundedAt'] == null
          ? null
          : DateTime.parse(json['refundedAt'] as String),
      refundMethod: json['refundMethod'] as String?,
      refundReason: json['refundReason'] as String?,
      cashRefundAmount: json['cashRefundAmount'] as int? ?? 0,
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
      paymentStatus: FirefaPaymentStatus.values.byName(
        json['paymentStatus'] as String,
      ),
    );
    return order;
  }
}
