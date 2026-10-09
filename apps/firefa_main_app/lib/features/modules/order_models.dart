enum FirefaOrderStatus {
  draft,
  confirmed,
  preparing,
  ready,
  served,
  completed,
  cancelled,
}

enum FirefaPaymentStatus { unpaid, paid }

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

  const FirefaOrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.details = '',
  });

  int get total => quantity * unitPrice;
}

class FirefaOrder {
  final String id;
  final String outletId;
  final String orderType;
  final String? tableId;
  final DateTime createdAt;
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
    return true;
  }

  bool cancel() {
    if (!status.canCancel || paymentStatus == FirefaPaymentStatus.paid) {
      return false;
    }
    status = FirefaOrderStatus.cancelled;
    return true;
  }

  bool markPaid() {
    if (status == FirefaOrderStatus.draft ||
        status == FirefaOrderStatus.cancelled ||
        paymentStatus == FirefaPaymentStatus.paid) {
      return false;
    }
    paymentStatus = FirefaPaymentStatus.paid;
    return true;
  }
}
