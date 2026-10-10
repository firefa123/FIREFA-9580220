class InventoryConflictResolutionFlow {
  bool resolveLocal(String conflictId) {
    return conflictId.isNotEmpty;
  }

  bool resolveServer(String conflictId) {
    return conflictId.isNotEmpty;
  }

  bool requestManualReview(String conflictId) {
    return conflictId.isNotEmpty;
  }
}
