/// FIREFA Conflict Resolution Handler
///
/// Connects owner decision with resolution workflow.
class ConflictResolutionHandler {
  final List<String> resolvedConflictIds = [];

  void resolve(String conflictId, String action) {
    resolvedConflictIds.add('$conflictId:$action');
  }

  bool isResolved(String conflictId) {
    return resolvedConflictIds.any((item) => item.startsWith(conflictId));
  }
}
