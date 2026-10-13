enum FirefaResolutionAction {
  keepLocal,
  acceptServer,
  manualReview,
}

class FirefaConflictResolution {
  final String conflictId;
  final FirefaResolutionAction action;
  final String actorId;
  final DateTime resolvedAt;

  const FirefaConflictResolution({
    required this.conflictId,
    required this.action,
    required this.actorId,
    required this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'conflictId': conflictId,
        'action': action.name,
        'actorId': actorId,
        'resolvedAt': resolvedAt.toUtc().toIso8601String(),
      };
}

class FirefaConflictResolutionPolicy {
  const FirefaConflictResolutionPolicy();

  FirefaResolutionAction defaultAction() {
    return FirefaResolutionAction.manualReview;
  }
}
