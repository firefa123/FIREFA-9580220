enum ConflictResolutionAction {
  keepLocal,
  acceptServer,
  manualReview,
}

class ConflictResolutionRecord {
  final String conflictId;
  final ConflictResolutionAction action;
  final String actor;
  final DateTime timestamp;

  ConflictResolutionRecord({
    required this.conflictId,
    required this.action,
    required this.actor,
    required this.timestamp,
  });
}
