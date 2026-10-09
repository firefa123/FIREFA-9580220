import 'offline_sync_queue.dart';

/// Immutable payload sent to the future FIREFA backend.
/// eventId is the idempotency key; orderId is only unique within the local
/// installation today and must not be treated as a global database key.
class FirefaSyncEnvelope {
  final String eventId;
  final String outletId;
  final String orderId;
  final String eventType;
  final DateTime createdAt;
  final Map<String, dynamic> orderSnapshot;

  FirefaSyncEnvelope({
    required this.eventId,
    required this.outletId,
    required this.orderId,
    required this.eventType,
    required this.createdAt,
    required Map<String, dynamic> orderSnapshot,
  }) : orderSnapshot = Map.unmodifiable(orderSnapshot);

  factory FirefaSyncEnvelope.fromEntry(FirefaSyncEntry entry) {
    return FirefaSyncEnvelope(
      eventId: entry.eventId,
      outletId: entry.outletId,
      orderId: entry.orderId,
      eventType: entry.eventType,
      createdAt: entry.createdAt,
      orderSnapshot: entry.orderSnapshot,
    );
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'outletId': outletId,
    'orderId': orderId,
    'eventType': eventType,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'orderSnapshot': orderSnapshot,
  };
}

enum FirefaSyncOutcome {
  acknowledged,
  retryableFailure,
  permanentFailure,
}

/// An acknowledgement must be verified against the event that was sent.
/// No adapter should report acknowledged based on an HTTP 2xx alone without
/// validating the backend response contract.
class FirefaSyncReceipt {
  final String eventId;
  final FirefaSyncOutcome outcome;
  final String? serverReference;
  final String? message;

  const FirefaSyncReceipt({
    required this.eventId,
    required this.outcome,
    this.serverReference,
    this.message,
  });

  bool acknowledges(FirefaSyncEnvelope event) =>
      outcome == FirefaSyncOutcome.acknowledged &&
      eventId == event.eventId &&
      serverReference != null &&
      serverReference!.isNotEmpty;
}

/// Transport contract only. This interface performs no network I/O itself.
/// Authentication, tenant/outlet authorization, TLS, idempotency and server
/// reconciliation must be implemented before enabling cloud synchronization.
abstract class FirefaSyncAdapter {
  const FirefaSyncAdapter();

  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event);
}

/// Safe default while no authenticated FIREFA backend is configured.
/// Deliberately does not claim successful synchronization.
class FirefaDisabledSyncAdapter extends FirefaSyncAdapter {
  const FirefaDisabledSyncAdapter();

  @override
  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event) async {
    return FirefaSyncReceipt(
      eventId: event.eventId,
      outcome: FirefaSyncOutcome.retryableFailure,
      message: 'Cloud belum terhubung. Event tetap tersimpan lokal.',
    );
  }
}
