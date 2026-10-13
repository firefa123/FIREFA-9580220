import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_models.dart';

enum FirefaSyncStatus { pending, syncing, synced, failed, conflict }

Object? _freezeJsonValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map(
        (key, nested) => MapEntry(key.toString(), _freezeJsonValue(nested)),
      ),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeJsonValue));
  }
  return value;
}

Map<String, dynamic> _immutableJsonMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.unmodifiable(
      value.map((key, nested) => MapEntry(key, _freezeJsonValue(nested))),
    );

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
  }) : orderSnapshot = _immutableJsonMap(orderSnapshot);

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
  Future<void>? _initialization;
  int _nextSequence = 1;
  final Random _random = Random.secure();
  Future<void> _pendingSave = Future<void>.value();

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _initialize().catchError((Object error) {
      // A failed read/validation must not poison the singleton forever. This
      // allows a corrected snapshot or a fresh local store to be initialized.
      _initialization = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    var recoveredInterruptedSend = false;
    if (raw != null && raw.isNotEmpty) {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final sequence = decoded['nextSequence'];
      final rawEntries = decoded['entries'];
      if (decoded['version'] != 1 ||
          sequence is! int ||
          sequence < 1 ||
          rawEntries is! List) {
        throw const FormatException('Snapshot outbox lokal tidak valid.');
      }

      // Parse and validate off to the side so corrupt persisted data cannot
      // partially replace the in-memory queue.
      final restored = rawEntries
          .map((value) => FirefaSyncEntry.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
      _validateEntries(restored);
      for (final entry in restored) {
        // Interrupted sends must be retried after a future backend exists.
        if (entry.status == FirefaSyncStatus.syncing) {
          entry.status = FirefaSyncStatus.pending;
          entry.nextAttemptAt = null;
          recoveredInterruptedSend = true;
        }
      }

      _entries
        ..clear()
        ..addAll(restored);
      _nextSequence = sequence;
    }
    _initialized = true;
    if (recoveredInterruptedSend) {
      _scheduleSave();
      await waitForPendingSave();
    }
    notifyListeners();
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

    // Reject malformed identities before allocating an event ID or mutating
    // the durable outbox. Outlet/order identity must match the snapshot sent
    // to the future backend.
    if (order.outletId.trim().isEmpty || order.id.trim().isEmpty) {
      throw ArgumentError('Outlet dan ID order wajib diisi untuk sinkronisasi.');
    }
    if (eventType.trim().isEmpty) {
      throw ArgumentError.value(eventType, 'eventType', 'Tidak boleh kosong.');
    }
    final snapshot = order.toJson();
    if (snapshot['outletId'] != order.outletId ||
        snapshot['id'] != order.id) {
      throw StateError('Identitas snapshot order tidak konsisten.');
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
      orderSnapshot: snapshot,
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
    if (previous != FirefaSyncStatus.pending &&
        previous != FirefaSyncStatus.syncing) {
      throw StateError(
        'Hanya event pending atau syncing yang dapat dijadwalkan ulang.',
      );
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
        if (entry.outletId != order.outletId || entry.orderId != order.id) {
          continue;
        }
        // Backups or migrations may not preserve list ordering. Select the
        // newest event by its durable timestamp rather than assuming the last
        // serialized entry always represents the latest local intent.
        if (latest == null ||
            !entry.createdAt.isBefore(latest.createdAt)) {
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

  void _validateEntries(List<FirefaSyncEntry> entries) {
    final eventIds = <String>{};
    for (final entry in entries) {
      if (entry.eventId.trim().isEmpty ||
          entry.outletId.trim().isEmpty ||
          entry.orderId.trim().isEmpty ||
          entry.eventType.trim().isEmpty ||
          entry.attempts < 0 ||
          !eventIds.add(entry.eventId) ||
          entry.orderSnapshot['id'] != entry.orderId ||
          entry.orderSnapshot['outletId'] != entry.outletId) {
        throw const FormatException(
          'Identitas atau status event pada snapshot outbox tidak valid.',
        );
      }
    }
  }

  /// Restore a combined snapshot and wait until it is durable.
  ///
  /// If persistence fails, the live queue is returned to its prior snapshot so
  /// callers never continue with an uncommitted outbox replacement.
  Future<void> restoreCombinedSnapshotDurably(
    Map<String, dynamic> data,
  ) async {
    _ensureInitialized();
    final previous = exportSnapshot();
    restoreCombinedSnapshot(data);
    try {
      await waitForPendingSave();
    } catch (error, stackTrace) {
      final previousEntries = (previous['entries'] as List)
          .map((value) => FirefaSyncEntry.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
      _entries
        ..clear()
        ..addAll(previousEntries);
      _nextSequence = previous['nextSequence'] as int;
      notifyListeners();
      try {
        _scheduleSave();
        await waitForPendingSave();
      } catch (_) {
        // Keep the original persistence error for the caller.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Used only when a validated combined snapshot is restored.
  void restoreCombinedSnapshot(Map<String, dynamic> data) {
    _ensureInitialized();

    // Validate the complete snapshot before touching the live queue. A corrupt
    // backup must not partially replace the current durable outbox.
    final rawEntries = data['entries'];
    final sequence = data['nextSequence'];
    if (data['version'] != 1 || rawEntries is! List ||
        sequence is! int || sequence < 1) {
      throw const FormatException('Snapshot outbox FIREFA tidak valid.');
    }

    late final List<FirefaSyncEntry> restored;
    try {
      restored = rawEntries
          .map((value) => FirefaSyncEntry.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
      _validateEntries(restored);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Isi event pada snapshot outbox tidak valid.');
    }
    for (final entry in restored) {
      if (entry.status == FirefaSyncStatus.syncing) {
        entry.status = FirefaSyncStatus.pending;
        entry.nextAttemptAt = null;
      }
    }

    _entries
      ..clear()
      ..addAll(restored);
    _nextSequence = sequence;
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
