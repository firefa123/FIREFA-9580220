import 'dart:convert';

import 'offline_sync_queue.dart';

/// Conflict detection is deliberately pure: it never overwrites local orders,
/// acknowledges an outbox event, or makes network requests.
enum FirefaConflictKind {
  concurrentEdit,
  duplicatePayment,
  inventoryDivergence,
  staleServerVersion,
  invalidServerResponse,
}

enum FirefaConflictAction { keepLocal, acceptServer, manualReview }

class FirefaSyncConflict {
  final String eventId;
  final String outletId;
  final String orderId;
  final FirefaConflictKind kind;
  final Map<String, dynamic> localSnapshot;
  final Map<String, dynamic> serverSnapshot;
  final DateTime detectedAt;

  FirefaSyncConflict({
    required this.eventId,
    required this.outletId,
    required this.orderId,
    required this.kind,
    required Map<String, dynamic> localSnapshot,
    required Map<String, dynamic> serverSnapshot,
    required this.detectedAt,
  })  : localSnapshot = Map.unmodifiable(localSnapshot),
        serverSnapshot = Map.unmodifiable(serverSnapshot);

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'outletId': outletId,
        'orderId': orderId,
        'kind': kind.name,
        'localSnapshot': localSnapshot,
        'serverSnapshot': serverSnapshot,
        'detectedAt': detectedAt.toUtc().toIso8601String(),
      };
}

class FirefaConflictManager {
  const FirefaConflictManager();

  /// Compare an outbox event with a server snapshot after validating identity.
  /// Returns null only for identical snapshots. A conflict must be reviewed
  /// before any mutation of orders, payments or inventory.
  FirefaSyncConflict? detect({
    required FirefaSyncEntry local,
    required String serverOutletId,
    required String serverOrderId,
    required Map<String, dynamic> serverSnapshot,
    FirefaConflictKind kind = FirefaConflictKind.concurrentEdit,
  }) {
    if (local.outletId != serverOutletId ||
        local.orderId != serverOrderId) {
      throw StateError('Server identity does not match local outbox event.');
    }
    if (_canonical(local.orderSnapshot) == _canonical(serverSnapshot)) {
      return null;
    }
    return FirefaSyncConflict(
      eventId: local.eventId,
      outletId: local.outletId,
      orderId: local.orderId,
      kind: kind,
      localSnapshot: local.orderSnapshot,
      serverSnapshot: serverSnapshot,
      detectedAt: DateTime.now().toUtc(),
    );
  }

  /// Safe decision policy. Payments and inventory require explicit review;
  /// other conflicts also default to manual review rather than last-write-wins.
  FirefaConflictAction recommendedAction(FirefaSyncConflict conflict) =>
      FirefaConflictAction.manualReview;

  String _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonical).join(',')}]';
    }
    return jsonEncode(value);
  }
}
