import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_models.dart';

Map<String, dynamic> _freezeJsonMap(Map<String, dynamic> source) {
  dynamic freeze(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, nested) => MapEntry(key.toString(), freeze(nested))),
      );
    }
    if (value is List) return List<dynamic>.unmodifiable(value.map(freeze));
    return value;
  }
  return freeze(source) as Map<String, dynamic>;
}

enum FirefaSyncStatus { pending, syncing, synced, failed, conflict }

class FirefaSyncEntry {
  final String eventId;
  final String outletId;
  final String orderId;
  final String eventType;
  final DateTime createdAt;
  final Map<String, dynamic> orderSnapshot;
  FirefaSyncStatus status;
  int attempts;
  DateTime? nextAttemptAt;

  FirefaSyncEntry({
    required this.eventId,
    required this.outletId,
    required this.orderId,
    required this.eventType,
    required this.createdAt,
    required Map<String, dynamic> orderSnapshot,
    this.status = FirefaSyncStatus.pending,
    this.attempts = 0,
    this.nextAttemptAt,
  }) : orderSnapshot = _freezeJsonMap(orderSnapshot);

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'outletId': outletId,
    'orderId': orderId,
    'eventType': eventType,
    'createdAt': createdAt.toIso8601String(),
    'orderSnapshot': orderSnapshot,
    'status': status.name,
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt?.toIso8601String(),
  };

  factory FirefaSyncEntry.fromJson(Map<String, dynamic> json) =>
      FirefaSyncEntry(
        eventId: json['eventId'] as String,
        outletId: json['outletId'] as String,
        orderId: json['orderId'] as String,
        eventType: json['eventType'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        orderSnapshot: Map<String, dynamic>.from(json['orderSnapshot'] as Map),
        status: FirefaSyncStatus.values.byName(json['status'] as String),
        attempts: (json['attempts'] as int?) ?? 0,
        nextAttemptAt: json['nextAttemptAt'] == null
            ? null
            : DateTime.parse(json['nextAttemptAt'] as String),
      );
}

/// Local-only sync outbox. No network requests or fake "synced" transitions.
class FirefaOfflineSyncQueue extends ChangeNotifier {
  FirefaOfflineSyncQueue._();
  static final FirefaOfflineSyncQueue instance = FirefaOfflineSyncQueue._();
  static const _storageKey = 'firefa_sync_outbox_v1';

  final List<FirefaSyncEntry> _entries = [];
  bool _initialized = false;
  int _nextSequence = 1;
  final Random _random = Random.secure();
  Future<void> _pendingSave = Future<void>.value();
  Future<void>? _initializing;

  Future<void> initialize() {
    if (_initialized) return _initializing ?? Future<void>.value();
    return _initializing ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      var nextSequence = 1;
      var restored = <FirefaSyncEntry>[];
      var recoveredInterruptedSend = false;
      if (raw != null && raw.isNotEmpty) {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        validateCombinedSnapshot(decoded);
        nextSequence = decoded['nextSequence'] as int;
        restored = (decoded['entries'] as List).map(
          (value) => FirefaSyncEntry.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ).toList();
        // Interrupted sends must be retried after a future backend exists.
        for (final entry in restored) {
          if (entry.status == FirefaSyncStatus.syncing) {
            entry.status = FirefaSyncStatus.pending;
            entry.nextAttemptAt = null;
            recoveredInterruptedSend = true;
          }
        }
      }
      _entries..clear()..addAll(restored);
      _nextSequence = nextSequence;
      _initialized = true;
      if (recoveredInterruptedSend) {
        _scheduleSave();
        await waitForPendingSave();
      }
      notifyListeners();
    } catch (_) {
      _entries.clear();
      _nextSequence = 1;
      _initialized = false;
      _initializing = null;
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Offline sync queue belum diinisialisasi.');
    }
  }

  List<FirefaSyncEntry> entriesForOutlet(String outletId) {
    _ensureInitialized();
    return List.unmodifiable(
      _entries.where((entry) => entry.outletId == outletId),
    );
  }

  int pendingCountForOutlet(String outletId) => entriesForOutlet(outletId)
      .where((entry) => entry.status == FirefaSyncStatus.pending)
      .length;

  /// Random 128-bit event IDs avoid collisions across installations.
  /// The future backend must still enforce idempotency on eventId.
  FirefaSyncEntry enqueueOrder(FirefaOrder order, String eventType) {
    _ensureInitialized();
    if (order.outletId.trim().isEmpty || order.id.trim().isEmpty || eventType.trim().isEmpty) {
      throw ArgumentError('Identitas outlet, order, dan event wajib diisi.');
    }
    final sequence = _nextSequence++;
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final nonce = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final event = FirefaSyncEntry(
      eventId: 'evt-$nonce-$sequence',
      outletId: order.outletId,
      orderId: order.id,
      eventType: eventType,
      createdAt: DateTime.now().toUtc(),
      orderSnapshot: order.toJson(),
    );
    _entries.add(event);
    _scheduleSave();
    notifyListeners();
    return event;
  }

  FirefaSyncEntry? findEvent(String eventId) {
    _ensureInitialized();
    for (final entry in _entries) {
      if (entry.eventId == eventId) return entry;
    }
    return null;
  }

  /// Persist the in-flight state and count this send attempt.
  Future<void> markSyncing(String eventId) async {
    _ensureInitialized();
    final entry = findEvent(eventId);
    if (entry == null) throw StateError('Event outbox tidak ditemukan.');
    if (entry.status != FirefaSyncStatus.pending) {
      throw StateError('Hanya event pending yang dapat diproses.');
    }
    final previousAttempts = entry.attempts;
    entry.status = FirefaSyncStatus.syncing;
    entry.nextAttemptAt = null;
    entry.attempts++;
    try {
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      entry.status = FirefaSyncStatus.pending;
      entry.attempts = previousAttempts;
      rethrow;
    }
    notifyListeners();
  }

  /// Return a non-acknowledged event to pending so a later retry can run.
  Future<void> markPending(
    String eventId, {
    Duration? retryDelay,
  }) async {
    _ensureInitialized();
    final entry = findEvent(eventId);
    if (entry == null) return;
    final previous = entry.status;
    final previousNextAttemptAt = entry.nextAttemptAt;
    if (previous == FirefaSyncStatus.failed ||
        previous == FirefaSyncStatus.synced ||
        previous == FirefaSyncStatus.conflict) {
      throw StateError('Event terminal tidak dapat kembali ke pending tanpa aksi eksplisit.');
    }
    if (previous == FirefaSyncStatus.pending && retryDelay == null) return;
    entry.status = FirefaSyncStatus.pending;
    entry.nextAttemptAt = retryDelay == null
        ? null
        : DateTime.now().toUtc().add(retryDelay);
    try {
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      entry.status = previous;
      entry.nextAttemptAt = previousNextAttemptAt;
      rethrow;
    }
    notifyListeners();
  }

  /// Keep conflicted events out of future send batches until reconciled.
  Future<void> markConflict(String eventId) async {
    _ensureInitialized();
    final entry = findEvent(eventId);
    if (entry == null) throw StateError('Event outbox tidak ditemukan.');
    if (entry.status != FirefaSyncStatus.syncing) {
      throw StateError('Hanya event yang sedang diproses dapat menjadi konflik.');
    }
    final previous = entry.status;
    final previousNextAttemptAt = entry.nextAttemptAt;
    entry.status = FirefaSyncStatus.conflict;
    entry.nextAttemptAt = null;
    try {
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      entry.status = previous;
      entry.nextAttemptAt = previousNextAttemptAt;
      rethrow;
    }
    notifyListeners();
  }

  /// Permanently rejected events require an explicit retry from the UI.
  Future<void> markFailed(String eventId) async {
    _ensureInitialized();
    final entry = findEvent(eventId);
    if (entry == null) throw StateError('Event outbox tidak ditemukan.');
    if (entry.status != FirefaSyncStatus.syncing) {
      throw StateError('Hanya event yang sedang diproses dapat ditandai gagal.');
    }
    final previous = entry.status;
    final previousNextAttemptAt = entry.nextAttemptAt;
    entry.status = FirefaSyncStatus.failed;
    entry.nextAttemptAt = null;
    try {
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      entry.status = previous;
      entry.nextAttemptAt = previousNextAttemptAt;
      rethrow;
    }
    notifyListeners();
  }

  /// Explicit user retry moves failed events for one outlet back to pending.
  Future<int> retryFailedForOutlet(String outletId) async {
    _ensureInitialized();
    final failed = _entries
        .where((entry) =>
            entry.outletId == outletId &&
            entry.status == FirefaSyncStatus.failed)
        .toList();
    if (failed.isEmpty) return 0;
    for (final entry in failed) {
      entry.status = FirefaSyncStatus.pending;
      entry.nextAttemptAt = null;
    }
    try {
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      for (final entry in failed) {
        entry.status = FirefaSyncStatus.failed;
      }
      rethrow;
    }
    notifyListeners();
    return failed.length;
  }

  /// Mark an event synced only after a verified backend acknowledgement.
  Future<void> markSynced(String eventId) async {
    _ensureInitialized();
    final entry = findEvent(eventId);
    if (entry == null) throw StateError('Event outbox tidak ditemukan.');
    if (entry.status != FirefaSyncStatus.syncing) {
      throw StateError('Hanya event yang sedang diproses dapat ditandai tersinkron.');
    }
    final previous = entry.status;
    final previousNextAttemptAt = entry.nextAttemptAt;
    entry.status = FirefaSyncStatus.synced;
    entry.nextAttemptAt = null;
    try {
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      entry.status = previous;
      entry.nextAttemptAt = previousNextAttemptAt;
      rethrow;
    }
    notifyListeners();
  }

  /// Remove an obsolete event after a conflict has been explicitly reconciled.
  /// The change is persisted before this method completes.
  Future<bool> removeEvent(String eventId) async {
    _ensureInitialized();
    final index = _entries.indexWhere((entry) => entry.eventId == eventId);
    if (index < 0) return false;
    final removed = _entries.removeAt(index);
    try {
      _scheduleSave();
      await waitForPendingSave();
    } catch (_) {
      _entries.insert(index, removed);
      rethrow;
    }
    notifyListeners();
    return true;
  }

  /// Reconcile restored orders with the latest durable event snapshot.
  /// Does not replay or send events; creates one repair event only when needed.
  int reconcileOrders(Iterable<FirefaOrder> orders) {
    _ensureInitialized();
    var repaired = 0;
    for (final order in orders) {
      FirefaSyncEntry? latest;
      for (final entry in _entries) {
        if (entry.outletId == order.outletId && entry.orderId == order.id &&
            (latest == null || entry.createdAt.isAfter(latest.createdAt))) {
          latest = entry;
        }
      }
      if (latest == null ||
          jsonEncode(latest.orderSnapshot) != jsonEncode(order.toJson())) {
        enqueueOrder(order, 'order.recovered');
        repaired++;
      }
    }
    return repaired;
  }

  /// Exported together with orders for one authoritative local snapshot.
  Map<String, dynamic> exportSnapshot() {
    _ensureInitialized();
    return {
      'version': 1,
      'nextSequence': _nextSequence,
      'entries': _entries.map((entry) => entry.toJson()).toList(),
    };
  }

  /// Validates a combined order/outbox snapshot without mutating live state.
  void validateCombinedSnapshot(Map<String, dynamic> data) {
    if (data['version'] != 1 ||
        data['entries'] is! List ||
        data['nextSequence'] is! int ||
        (data['nextSequence'] as int) < 1) {
      throw const FormatException('Struktur backup antrean sync tidak valid.');
    }

    try {
      final eventIds = <String>{};
      for (final value in data['entries'] as List) {
        final entry = FirefaSyncEntry.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        final order = FirefaOrder.fromJson(entry.orderSnapshot);
        if (entry.eventId.trim().isEmpty ||
            entry.outletId.trim().isEmpty ||
            entry.orderId.trim().isEmpty ||
            entry.eventType.trim().isEmpty ||
            entry.attempts < 0 ||
            !eventIds.add(entry.eventId) ||
            order.id != entry.orderId ||
            order.outletId != entry.outletId) {
          throw const FormatException(
            'Data event pada backup antrean sync tidak valid.',
          );
        }
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Data event pada backup antrean sync tidak valid.',
      );
    }
  }

  /// Used only when a validated combined snapshot is restored.
  /// Merge the combined order/outbox snapshot with the dedicated outbox.
  /// The dedicated outbox is written on every state transition, so when an
  /// event exists in both places its state is authoritative. Events present
  /// only in the combined snapshot are recovered instead of being discarded.
  void restoreCombinedSnapshot(
    Map<String, dynamic> data, {
    bool mergeOutbox = true,
  }) {
    _ensureInitialized();
    validateCombinedSnapshot(data);
    final combinedEntries = (data['entries'] as List)
        .map((value) => FirefaSyncEntry.fromJson(
              Map<String, dynamic>.from(value as Map),
            ))
        .toList();
    final restoredById = <String, FirefaSyncEntry>{
      if (mergeOutbox) for (final entry in _entries) entry.eventId: entry,
    };
    for (final entry in combinedEntries) {
      restoredById.putIfAbsent(entry.eventId, () => entry);
    }
    for (final entry in restoredById.values) {
      if (entry.status == FirefaSyncStatus.syncing) {
        entry.status = FirefaSyncStatus.pending;
        entry.nextAttemptAt = null;
      }
    }
    _entries
      ..clear()
      ..addAll(restoredById.values);
    final combinedSequence = data['nextSequence'] as int;
    if (mergeOutbox) {
      if (combinedSequence > _nextSequence) _nextSequence = combinedSequence;
    } else {
      _nextSequence = combinedSequence;
    }
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    final snapshot = jsonEncode({
      'version': 1,
      'nextSequence': _nextSequence,
      'entries': _entries.map((entry) => entry.toJson()).toList(),
    });
    _pendingSave = _pendingSave
        .catchError((Object error) {
          debugPrint('FIREFA outbox previous write failed: $error');
        })
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(_storageKey, snapshot)) {
            throw StateError('Gagal menyimpan offline sync queue.');
          }
        });
    unawaited(_pendingSave.catchError((Object error) {
      debugPrint('FIREFA outbox write failed: $error');
    }));
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
