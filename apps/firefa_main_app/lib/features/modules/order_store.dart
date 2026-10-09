import 'package:flutter/foundation.dart';

import 'order_models.dart';

class FirefaOrderStore extends ChangeNotifier {
  FirefaOrderStore._();

  static final FirefaOrderStore instance = FirefaOrderStore._();

  final List<FirefaOrder> _orders = [];
  int _nextNumber = 1001;

  List<FirefaOrder> ordersForOutlet(String outletId) {
    return List.unmodifiable(
      _orders.where((order) => order.outletId == outletId),
    );
  }

  FirefaOrder createOrder({
    required String outletId,
    required String orderType,
    required String? tableId,
    required List<FirefaOrderItem> items,
    required int subtotal,
    required int discount,
    required int tax,
    required int service,
    required int total,
  }) {
    if (outletId.trim().isEmpty) {
      throw ArgumentError('Outlet wajib dipilih.');
    }
    if (items.isEmpty || total < 0) {
      throw ArgumentError('Pesanan tidak valid.');
    }
    if (orderType == 'Dine In' && (tableId == null || tableId.isEmpty)) {
      throw ArgumentError('Nomor meja wajib dipilih.');
    }
    if (subtotal < 0 ||
        discount < 0 ||
        tax < 0 ||
        service < 0 ||
        discount > subtotal ||
        subtotal - discount + tax + service != total) {
      throw ArgumentError('Perhitungan pesanan tidak valid.');
    }

    final order = FirefaOrder(
      id: 'ORD-${_nextNumber++}',
      outletId: outletId,
      orderType: orderType,
      tableId: orderType == 'Dine In' ? tableId : null,
      createdAt: DateTime.now(),
      items: List.unmodifiable(items),
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      service: service,
      total: total,
    );

    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  FirefaOrder? findOrder(String outletId, String orderId) {
    for (final order in _orders) {
      if (order.outletId == outletId && order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  bool advance(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);
    if (order == null || !order.advanceStatus()) return false;
    notifyListeners();
    return true;
  }

  bool cancel(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);
    if (order == null || !order.cancel()) return false;
    notifyListeners();
    return true;
  }

  bool markPaid(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);
    if (order == null || !order.markPaid()) return false;
    notifyListeners();
    return true;
  }
}
