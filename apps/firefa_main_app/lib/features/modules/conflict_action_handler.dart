import 'conflict_store.dart';
import 'conflict_management.dart';

/// Applies only the administrative decision record. Actual data mutation must
/// be handled by the relevant domain service after validation.
class FirefaConflictActionHandler {
  final FirefaConflictStore store;

  const FirefaConflictActionHandler(this.store);

  Future<FirefaConflictResolutionAudit> resolve({
    required FirefaSyncConflict conflict,
    required FirefaConflictAction action,
    required String actorId,
  }) async {
    final audit = FirefaConflictResolutionAudit(
      eventId: conflict.eventId,
      orderId: conflict.orderId,
      action: action,
      actorId: actorId,
      resolvedAt: DateTime.now().toUtc(),
    );

    await store.remove(conflict.eventId);
    return audit;
  }
}

class FirefaConflictResolutionAudit {
  final String eventId;
  final String orderId;
  final FirefaConflictAction action;
  final String actorId;
  final DateTime resolvedAt;

  const FirefaConflictResolutionAudit({
    required this.eventId,
    required this.orderId,
    required this.action,
    required this.actorId,
    required this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'orderId': orderId,
        'action': action.name,
        'actorId': actorId,
        'resolvedAt': resolvedAt.toIso8601String(),
      };
}
