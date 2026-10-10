class ConflictAuditEntry {
  final String conflictId;
  final String action;
  final String actor;
  final DateTime timestamp;

  ConflictAuditEntry({
    required this.conflictId,
    required this.action,
    required this.actor,
    required this.timestamp,
  });
}

class ConflictAuditTimeline {
  final List<ConflictAuditEntry> entries = [];

  void add(ConflictAuditEntry entry) {
    entries.add(entry);
  }

  List<ConflictAuditEntry> byConflict(String id) {
    return entries.where((e) => e.conflictId == id).toList();
  }
}
