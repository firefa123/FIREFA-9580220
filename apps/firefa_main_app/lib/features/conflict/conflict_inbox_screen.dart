/// FIREFA Owner Conflict Inbox Screen Foundation
///
/// Prepares conflict list presentation for owner resolution workflow.
class ConflictInboxItem {
  final String id;
  final String type;
  final String status;
  final DateTime detectedAt;

  const ConflictInboxItem({
    required this.id,
    required this.type,
    required this.status,
    required this.detectedAt,
  });
}

class ConflictInboxScreenModel {
  final List<ConflictInboxItem> pendingConflicts;

  const ConflictInboxScreenModel({
    this.pendingConflicts = const [],
  });

  int get pendingCount => pendingConflicts.length;
}
