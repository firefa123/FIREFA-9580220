import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_models.dart';
import 'offline_sync_queue.dart';

class FirefaOrderStore extends ChangeNotifier {
  FirefaOrderStore._();

  static final FirefaOrderStore instance = FirefaOrderStore._();

  static const String _storageKey = 'firefa_orders_v1';
  static const String _combinedKey = 'firefa_orders_outbox_v2';

  final List<FirefaOrder> _orders = [];

  int _nextNumber = 1001;
  bool _initialized = false;

  Future<void> _pendingSave = Future.value();

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final combinedRaw = prefs.getString(_combinedKey);
    final raw = combinedRaw ?? prefs.getString(_storageKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;

        final restoredOrders = (decoded['orders'] as List)
            .map(
              (entry) =>
                  FirefaOrder.fromJson(Map<String, dynamic>.from(entry as Map)),
            )
            .toList();

        final savedNumber = decoded['nextNumber'] as int;
        if (combinedRaw != null) {
          // Parse both halves before applying either one.
          final outbox = Map<String, dynamic>.from(decoded['outbox'] as Map);
          FirefaOfflineSyncQueue.instance.restoreCombinedSnapshot(outbox);
        }

        _orders
          ..clear()
          ..addAll(restoredOrders);

        _nextNumber = savedNumber;
      } catch (error) {
        // Jangan menimpa data lama jika format gagal dibaca.
        debugPrint('FIREFA: gagal membaca offline orders: $error');
        rethrow;
      }
    }

    // Repair missing outbox events after a prior interrupted write.
    // Legacy local orders are also registered for future synchronization.
    final repairs = FirefaOfflineSyncQueue.instance.reconcileOrders(_orders);

    _initialized = true;
    if (combinedRaw == null || repairs > 0) {
      _scheduleSave();
    }
    notifyListeners();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'FirefaOrderStore.initialize() harus dipanggil '
        'sebelum menggunakan pesanan.',
      );
    }
  }

  void _scheduleSave() {
    final snapshot = jsonEncode({
      'version': 2,
      'nextNumber': _nextNumber,
      'orders': _orders.map((order) => order.toJson()).toList(),
      'outbox': FirefaOfflineSyncQueue.instance.exportSnapshot(),
    });

    _pendingSave = _pendingSave
        .catchError((Object error) {
          debugPrint('FIREFA: penyimpanan sebelumnya gagal: $error');
        })
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          final success = await prefs.setString(_combinedKey, snapshot);

          if (!success) {
            throw StateError('Gagal menyimpan offline orders.');
          }
        });

    unawaited(
      _pendingSave.catchError((Object error) {
        debugPrint('FIREFA: gagal menyimpan offline orders: $error');
      }),
    );
  }

  Future<void> waitForPendingSave() async {
    await _pendingSave;
    await FirefaOfflineSyncQueue.instance.waitForPendingSave();
  }

  List<FirefaOrder> ordersForOutlet(String outletId) {
    _ensureInitialized();

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
    _ensureInitialized();

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

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.created');
    _scheduleSave();
    notifyListeners();

    return order;
  }

  FirefaOrder? findOrder(String outletId, String orderId) {
    _ensureInitialized();

    for (final order in _orders) {
      if (order.outletId == outletId && order.id == orderId) {
        return order;
      }
    }

    return null;
  }

  bool advance(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);

    if (order == null || !order.advanceStatus()) {
      return false;
    }

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    notifyListeners();
    return true;
  }

  bool cancel(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);

    if (order == null || !order.cancel()) {
      return false;
    }

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    notifyListeners();
    return true;
  }

  bool markPaid(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);

    if (order == null || !order.markPaid()) {
      return false;
    }

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    notifyListeners();
    return true;
  }
}
