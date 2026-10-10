import 'conflict_resolution_actions.dart';

class OwnerConflictItem {
  final String id;
  final String title;
  final String category;
  final String localValue;
  final String serverValue;
  final bool resolved;

  const OwnerConflictItem({
    required this.id,
    required this.title,
    required this.category,
    required this.localValue,
    required this.serverValue,
    this.resolved = false,
  });
}

class OwnerConflictCenterViewModel {
  final List<OwnerConflictItem> conflicts;

  const OwnerConflictCenterViewModel(this.conflicts);

  List<OwnerConflictItem> get pending =>
      conflicts.where((item) => !item.resolved).toList(growable: false);

  int get pendingCount => pending.length;

  String resolvePreview(
    OwnerConflictItem item,
    ConflictResolutionAction action,
  ) {
    return '${action.label}: ${item.id}';
  }
}
