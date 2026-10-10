import 'package:flutter/foundation.dart';

import 'conflict_resolution_model.dart';

/// Local decision history for owner-approved conflict resolutions.
///
/// This layer intentionally stores decisions separately from detection so
/// conflict discovery and resolution remain independently testable.
class ConflictResolutionStore extends ChangeNotifier {
  final List<ConflictResolutionRecord> _records = [];

  List<ConflictResolutionRecord> get records => List.unmodifiable(_records);

  List<ConflictResolutionRecord> byConflictId(String conflictId) {
    return _records
        .where((record) => record.conflictId == conflictId)
        .toList(growable: false);
  }

  void resolve({
    required String conflictId,
    required ConflictResolutionAction action,
    required String actor,
  }) {
    _records.add(
      ConflictResolutionRecord(
        conflictId: conflictId,
        action: action,
        actor: actor,
        resolvedAt: DateTime.now().toUtc(),
      ),
    );
    notifyListeners();
  }

  bool isResolved(String conflictId) {
    return _records.any((record) => record.conflictId == conflictId);
  }
}
