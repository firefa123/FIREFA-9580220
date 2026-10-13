import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_models.dart';
import 'offline_sync_queue.dart';
import 'inventory_store.dart';
import 'table_store.dart';

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

    // Order loading and outbox reconciliation both depend on the queue being
    // ready, including in tests and fresh offline installations.
    await FirefaOfflineSyncQueue.instance.initialize();

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

  Map<String, dynamic> exportLocalSnapshot() {
    _ensureInitialized();

    return {
      'version': 2,
      'nextNumber': _nextNumber,
      'orders': _orders.map((order) => order.toJson()).toList(),
      'outbox': FirefaOfflineSyncQueue.instance.exportSnapshot(),
    };
  }

  void restoreLocalSnapshot(Map<String, dynamic> snapshot) {
    _ensureInitialized();

    if (snapshot['version'] != 2) {
      throw const FormatException('Versi backup tidak didukung.');
    }

    final nextNumber = snapshot['nextNumber'];
    final rawOrders = snapshot['orders'];
    final rawOutbox = snapshot['outbox'];

    if (nextNumber is! int || rawOrders is! List || rawOutbox is! Map) {
      throw const FormatException('Struktur backup FIREFA tidak valid.');
    }

    final restoredOrders = rawOrders
        .map(
          (entry) =>
              FirefaOrder.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();

    final restoredOutbox = Map<String, dynamic>.from(rawOutbox);

    // Parse both sides completely before mutating active local state.
    FirefaOfflineSyncQueue.instance.restoreCombinedSnapshot(restoredOutbox);

    _orders
      ..clear()
      ..addAll(restoredOrders);
    _nextNumber = nextNumber;

    FirefaOfflineSyncQueue.instance.reconcileOrders(_orders);
    _scheduleSave();
    notifyListeners();
  }

  /// Keeps table availability aligned with all active dine-in orders.
  /// Table IDs in legacy POS orders are stored as table names, so matching is
  /// intentionally outlet-scoped and name-based for backward compatibility.
  Future<void> _syncTableOccupancyForOrder(FirefaOrder order) async {
    if (order.orderType != 'Dine In' || order.tableId == null) return;

    try {
      final tables = FirefaTableStore.instance;
      await tables.initialize();
      final activeOrders = _orders.where((candidate) =>
        candidate.outletId == order.outletId &&
        candidate.orderType == 'Dine In' &&
        candidate.tableId == order.tableId &&
        candidate.status != FirefaOrderStatus.completed &&
        candidate.status != FirefaOrderStatus.cancelled
      );
      final shouldBeOccupied = activeOrders.isNotEmpty;
      for (final table in tables.forOutlet(order.outletId).where(
        (candidate) => candidate.name == order.tableId,
      )) {
        if (table.occupied != shouldBeOccupied) {
          tables.setOccupied(order.outletId, table.id, shouldBeOccupied);
        }
      }
      await tables.waitForPendingSave();
    } catch (error) {
      // Orders remain authoritative; the next table/order action can retry.
      debugPrint('FIREFA: sinkronisasi status meja tertunda: $error');
    }
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

  /// Apply an explicit conflict decision to the real local order and outbox.
  /// Server snapshots are accepted only after full model parsing and identity checks.
  Future<void> reconcileConflict({
    required String eventId,
    required String outletId,
    required String orderId,
    required bool acceptServer,
    Map<String, dynamic>? serverSnapshot,
  }) async {
    _ensureInitialized();
    final index = _orders.indexWhere(
      (order) => order.outletId == outletId && order.id == orderId,
    );
    if (index < 0) {
      throw StateError('Order lokal tidak ditemukan untuk konflik ini.');
    }

    final previousOrder = _orders[index];
    final queue = FirefaOfflineSyncQueue.instance;
    final matchingEvent = queue.entriesForOutlet(outletId).where(
      (entry) => entry.eventId == eventId && entry.orderId == orderId,
    );
    final hasConflictedEvent = matchingEvent.isNotEmpty;
    if (!hasConflictedEvent &&
        queue.entriesForOutlet(outletId).any((entry) => entry.eventId == eventId)) {
      throw StateError('Event konflik ditemukan pada order yang berbeda.');
    }

    // Idempotency: a prior attempt may have persisted the order but failed
    // before the inbox/audit update. Allow retry when the event is already gone.
    FirefaOrder nextOrder = previousOrder;
    if (acceptServer) {
      if (serverSnapshot == null) {
        throw ArgumentError('Snapshot server wajib tersedia untuk Accept Server.');
      }
      final parsed = FirefaOrder.fromJson(Map<String, dynamic>.from(serverSnapshot));
      if (parsed.id != orderId || parsed.outletId != outletId) {
        throw StateError('Identitas snapshot server tidak cocok dengan order aktif.');
      }
      final itemSubtotal = parsed.items.fold<int>(
        0,
        (sum, item) => sum + item.total,
      );
      final hasInvalidItem = parsed.items.any(
        (item) =>
            item.productName.trim().isEmpty ||
            item.quantity <= 0 ||
            item.unitPrice < 0,
      );
      if (parsed.total < 0 ||
          parsed.subtotal < 0 ||
          parsed.discount < 0 ||
          parsed.tax < 0 ||
          parsed.service < 0 ||
          parsed.discount > parsed.subtotal ||
          parsed.subtotal - parsed.discount + parsed.tax + parsed.service !=
              parsed.total ||
          parsed.items.isEmpty ||
          hasInvalidItem ||
          itemSubtotal != parsed.subtotal) {
        throw FormatException('Snapshot server melanggar validasi order.');
      }
      nextOrder = parsed;
    }

    // Update the authoritative local order, then retire the stale event. For
    // Keep Local, enqueue a fresh event ID so the retained snapshot can retry.
    _orders[index] = nextOrder;
    try {
      if (hasConflictedEvent) {
        await queue.removeEvent(eventId);
      }
      if (!acceptServer) {
        final alreadyQueued = queue.entriesForOutlet(outletId).any(
          (entry) =>
              entry.orderId == orderId &&
              entry.eventType == 'order.updated' &&
              jsonEncode(entry.orderSnapshot) == jsonEncode(nextOrder.toJson()),
        );
        if (!alreadyQueued) {
          queue.enqueueOrder(nextOrder, 'order.updated');
        }
      }
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      _orders[index] = previousOrder;
      _scheduleSave();
      rethrow;
    }
    notifyListeners();
  }

  bool advance(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);

    if (order == null || !order.advanceStatus()) {
      return false;
    }

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    notifyListeners();
    if (order.status == FirefaOrderStatus.completed) {
      unawaited(_syncTableOccupancyForOrder(order));
    }
    return true;
  }

  /// Cancels an unpaid order and restores ingredients previously deducted by POS.
  /// The local order and inventory stores persist separately, so this remains a
  /// local-first best effort rather than a crash-atomic cross-store transaction.
  Future<bool> cancelAndRestoreStock(String outletId, String orderId) async {
    final order = findOrder(outletId, orderId);
    if (order == null || !order.status.canCancel ||
        order.paymentStatus == FirefaPaymentStatus.paid) {
      return false;
    }

    // Change the order state before the first await so another action cannot
    // pay or advance it while stock restoration is in flight.
    final previousStatus = order.status;
    if (!order.cancel()) return false;

    try {
      final inventory = FirefaInventoryStore.instance;
      await inventory.initialize();
      if (inventory.isOrderStockProcessed(orderId) &&
          !inventory.isOrderStockReversed(orderId)) {
        await inventory.restoreCancelledOrderStock(
          orderId: orderId,
          outletId: outletId,
        );
      }
    } catch (_) {
      // Keep the order cancellable if restoration could not be completed.
      order.status = previousStatus;
      _scheduleSave();
      notifyListeners();
      rethrow;
    }

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    await waitForPendingSave();
    notifyListeners();
    await _syncTableOccupancyForOrder(order);
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
    unawaited(_syncTableOccupancyForOrder(order));
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
