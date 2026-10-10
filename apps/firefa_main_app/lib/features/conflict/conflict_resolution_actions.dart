enum ConflictResolutionAction {
  keepLocal,
  acceptServer,
  manualReview,
}

extension ConflictResolutionActionLabel on ConflictResolutionAction {
  String get label {
    switch (this) {
      case ConflictResolutionAction.keepLocal:
        return 'Keep Local';
      case ConflictResolutionAction.acceptServer:
        return 'Accept Server';
      case ConflictResolutionAction.manualReview:
        return 'Manual Review';
    }
  }
}
