import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_models.dart';
import 'offline_sync_queue.dart';
import 'inventory_store.dart';

class FirefaOrderStore extends ChangeNotifier {
  FirefaOrderStore._();

  static final FirefaOrderStore instance = FirefaOrderStore._();

  static const String _storageKey = 'firefa_orders_v1';
  static const String _combinedKey = 'firefa_orders_outbox_v2';

  final List<FirefaOrder> _orders = [];
  final Set<String> _cancellationsInProgress = <String>{};

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
        _validateRestoredOrders(restoredOrders);
        if (savedNumber < 1) {
          throw const FormatException('Nomor urut order tidak valid.');
        }
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

  void _validateRestoredOrders(List<FirefaOrder> orders) {
    final identities = <String>{};
    for (final order in orders) {
      if (order.id.trim().isEmpty || order.outletId.trim().isEmpty) {
        throw const FormatException(
          'ID order dan outlet wajib terisi pada backup.',
        );
      }
      final identity = '${order.outletId}\u0000${order.id}';
      if (!identities.add(identity)) {
        throw const FormatException(
          'Backup berisi ID order duplikat dalam outlet yang sama.',
        );
      }
      if (order.items.isEmpty ||
          order.items.any((item) =>
              item.productName.trim().isEmpty ||
              item.quantity <= 0 ||
              item.unitPrice < 0)) {
        throw const FormatException(
          'Backup berisi detail item order yang tidak valid.',
        );
      }
      final calculatedSubtotal =
          order.items.fold<int>(0, (sum, item) => sum + item.total);
      if (order.subtotal != calculatedSubtotal ||
          order.discount < 0 ||
          order.tax < 0 ||
          order.service < 0 ||
          order.discount > order.subtotal ||
          order.total !=
              order.subtotal - order.discount + order.tax + order.service) {
        throw const FormatException(
          'Backup berisi snapshot keuangan order yang tidak konsisten.',
        );
      }
    }
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
    _validateRestoredOrders(restoredOrders);
    if (nextNumber < 1) {
      throw const FormatException('Nomor urut order tidak valid.');
    }

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

  /// Restores a validated backup and waits for the combined order/outbox
  /// snapshot to persist. On failure, restore the previous in-memory state and
  /// make a best-effort durable rollback before propagating the original error.
  Future<void> restoreLocalSnapshotDurably(
    Map<String, dynamic> snapshot,
  ) async {
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
        .map((entry) => FirefaOrder.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ))
        .toList();
    final restoredOutbox = Map<String, dynamic>.from(rawOutbox);
    _validateRestoredOrders(restoredOrders);
    if (nextNumber < 1) {
      throw const FormatException('Nomor urut order tidak valid.');
    }

    final queue = FirefaOfflineSyncQueue.instance;
    final previousOrders = List<FirefaOrder>.from(_orders);
    final previousNextNumber = _nextNumber;
    final previousOutbox = queue.exportSnapshot();

    await queue.restoreCombinedSnapshotDurably(restoredOutbox);
    try {
      _orders
        ..clear()
        ..addAll(restoredOrders);
      _nextNumber = nextNumber;
      queue.reconcileOrders(_orders);
      _scheduleSave();
      await waitForPendingSave();
      notifyListeners();
    } catch (error, stackTrace) {
      _orders
        ..clear()
        ..addAll(previousOrders);
      _nextNumber = previousNextNumber;
      try {
        await queue.restoreCombinedSnapshotDurably(previousOutbox);
        _scheduleSave();
        await waitForPendingSave();
      } catch (_) {
        // Preserve the initial failure; next startup reconciles local snapshots.
      }
      notifyListeners();
      Error.throwWithStackTrace(error, stackTrace);
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

    if (orderType.trim().isEmpty || items.isEmpty || total < 0) {
      throw ArgumentError('Pesanan tidak valid.');
    }

    if (orderType == 'Dine In' &&
        (tableId == null || tableId.trim().isEmpty)) {
      throw ArgumentError('Nomor meja wajib dipilih.');
    }

    final hasInvalidItem = items.any(
      (item) =>
          item.productName.trim().isEmpty ||
          item.quantity <= 0 ||
          item.unitPrice < 0,
    );
    if (hasInvalidItem) {
      throw ArgumentError('Detail item pesanan tidak valid.');
    }

    // The financial snapshot must agree with the actual item lines. This
    // prevents callers from storing a total that cannot be explained by the
    // order contents, including when the order is later synced offline.
    final calculatedSubtotal = items.fold<int>(
      0,
      (sum, item) => sum + item.total,
    );

    if (subtotal < 0 ||
        discount < 0 ||
        tax < 0 ||
        service < 0 ||
        discount > subtotal ||
        calculatedSubtotal != subtotal ||
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
    final existingEvent = queue.findEvent(eventId);
    if (existingEvent != null &&
        (existingEvent.outletId != outletId || existingEvent.orderId != orderId)) {
      throw StateError('Identitas event konflik tidak cocok dengan order aktif.');
    }
    if (existingEvent != null &&
        existingEvent.status != FirefaSyncStatus.conflict) {
      throw StateError('Hanya event berstatus konflik yang dapat direkonsiliasi.');
    }
    // A missing event is allowed for an idempotent retry after a previous
    // attempt removed the outbox entry but failed to finish durable local save.
    final hasConflictedEvent = existingEvent != null;

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

  String _orderKey(String outletId, String orderId) =>
      '$outletId\u0000$orderId';

  bool advance(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);

    if (order == null ||
        _cancellationsInProgress.contains(_orderKey(outletId, orderId)) ||
        !order.advanceStatus()) {
      return false;
    }

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    notifyListeners();
    return true;
  }

  /// Cancels an unpaid order and restores ingredients previously deducted by POS.
  /// The local order and inventory stores persist separately, so this remains a
  /// local-first best effort rather than a crash-atomic cross-store transaction.
  Future<bool> cancelAndRestoreStock(String outletId, String orderId) async {
    final order = findOrder(outletId, orderId);
    final key = _orderKey(outletId, orderId);
    if (order == null ||
        _cancellationsInProgress.contains(key) ||
        !order.status.canCancel ||
        order.paymentStatus == FirefaPaymentStatus.paid) {
      return false;
    }

    // Lock before awaiting so payment or status changes cannot race cancellation.
    _cancellationsInProgress.add(key);
    try {
      final inventory = FirefaInventoryStore.instance;
      final queue = FirefaOfflineSyncQueue.instance;
      await inventory.initialize();
      await queue.initialize();

      final previousStatus = order.status;
      if (!order.cancel()) return false;

      // Persist the cancellation intent first. If order persistence fails, stock
      // is still untouched and the caller can safely retry the operation.
      try {
        queue.enqueueOrder(order, 'order.updated');
        _scheduleSave();
        await waitForPendingSave();
      } catch (error, stackTrace) {
        order.status = previousStatus;
        try {
          queue.enqueueOrder(order, 'order.updated');
          _scheduleSave();
          await waitForPendingSave();
        } catch (_) {
          // Keep the original error; startup reconciliation repairs the outbox.
        }
        notifyListeners();
        Error.throwWithStackTrace(error, stackTrace);
      }

      // Stock restoration has its own durable rollback. If it fails, restore
      // the previous order status and enqueue that compensating local snapshot.
      try {
        if (inventory.isOrderStockProcessed(orderId, outletId: outletId) &&
            !inventory.isOrderStockReversed(orderId, outletId: outletId)) {
          await inventory.restoreCancelledOrderStock(
            orderId: orderId,
            outletId: outletId,
          );
        }
      } catch (error, stackTrace) {
        order.status = previousStatus;
        try {
          queue.enqueueOrder(order, 'order.updated');
          _scheduleSave();
          await waitForPendingSave();
        } catch (_) {
          // Preserve the stock-restoration failure for the caller.
        }
        notifyListeners();
        Error.throwWithStackTrace(error, stackTrace);
      }

      notifyListeners();
      return true;
    } finally {
      _cancellationsInProgress.remove(key);
    }
  }

  bool cancel(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);
    if (order == null ||
        _cancellationsInProgress.contains(_orderKey(outletId, orderId))) {
      return false;
    }

    // A synchronous cancellation cannot safely restore recipe stock. Force
    // stock-processed orders through cancelAndRestoreStock so cancellation
    // cannot silently leave inventory deducted.
    final inventory = FirefaInventoryStore.instance;
    if (inventory.isOrderStockProcessed(orderId, outletId: outletId) &&
        !inventory.isOrderStockReversed(orderId, outletId: outletId)) {
      return false;
    }

    if (!order.cancel()) return false;

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    notifyListeners();
    return true;
  }

  bool markPaid(String outletId, String orderId) {
    final order = findOrder(outletId, orderId);

    if (order == null ||
        _cancellationsInProgress.contains(_orderKey(outletId, orderId)) ||
        !order.markPaid()) {
      return false;
    }

    FirefaOfflineSyncQueue.instance.enqueueOrder(order, 'order.updated');
    _scheduleSave();
    notifyListeners();
    return true;
  }
}
