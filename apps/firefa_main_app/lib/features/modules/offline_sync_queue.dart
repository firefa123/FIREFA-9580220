import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_models.dart';

enum FirefaSyncStatus { pending, syncing, synced, failed }

class FirefaSyncEntry {
  final String eventId;
  final String outletId;
  final String orderId;
  final String eventType;
  final DateTime createdAt;
  final Map<String, dynamic> orderSnapshot;
  FirefaSyncStatus status;
  int attempts;

  FirefaSyncEntry({
    required this.eventId,
    required this.outletId,
    required this.orderId,
    required this.eventType,
    required this.createdAt,
    required this.orderSnapshot,
    this.status = FirefaSyncStatus.pending,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'outletId': outletId,
    'orderId': orderId,
    'eventType': eventType,
    'createdAt': createdAt.toIso8601String(),
    'orderSnapshot': orderSnapshot,
    'status': status.name,
    'attempts': attempts,
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
        attempts: json['attempts'] as int,
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

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _nextSequence = decoded['nextSequence'] as int;
      _entries
        ..clear()
        ..addAll((decoded['entries'] as List).map(
          (value) => FirefaSyncEntry.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ));
      // Interrupted sends must be retried after a future backend exists.
      for (final entry in _entries) {
        if (entry.status == FirefaSyncStatus.syncing) {
          entry.status = FirefaSyncStatus.pending;
        }
      }
    }
    _initialized = true;
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

  /// Reconcile restored orders with the latest durable event snapshot.
  /// Does not replay or send events; creates one repair event only when needed.
  int reconcileOrders(Iterable<FirefaOrder> orders) {
    _ensureInitialized();
    var repaired = 0;
    for (final order in orders) {
      FirefaSyncEntry? latest;
      for (final entry in _entries) {
        if (entry.outletId == order.outletId && entry.orderId == order.id) {
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

  /// Used only when a validated combined snapshot is restored.
  void restoreCombinedSnapshot(Map<String, dynamic> data) {
    _ensureInitialized();
    final restored = (data['entries'] as List)
        .map((value) => FirefaSyncEntry.fromJson(
              Map<String, dynamic>.from(value as Map),
            ))
        .toList();
    final sequence = data['nextSequence'] as int;
    _entries
      ..clear()
      ..addAll(restored);
    _nextSequence = sequence;
    for (final entry in _entries) {
      if (entry.status == FirefaSyncStatus.syncing) {
        entry.status = FirefaSyncStatus.pending;
      }
    }
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
