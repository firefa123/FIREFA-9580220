import 'package:flutter/foundation.dart';

import 'conflict_resolution_model.dart';

/// Local decision history for owner-approved conflict resolutions.
///
/// Detection and resolution remain separate so each layer can be tested
/// independently. A recorded decision is an audit entry; it does not mutate
/// orders, payments, or inventory by itself.
class ConflictResolutionStore extends ChangeNotifier {
  final List<FirefaConflictResolution> _records = [];

  List<FirefaConflictResolution> get records =>
      List.unmodifiable(_records);

  List<FirefaConflictResolution> byConflictId(String conflictId) {
    return _records
        .where((record) => record.conflictId == conflictId)
        .toList(growable: false);
  }

  void resolve({
    required String conflictId,
    required FirefaResolutionAction action,
    required String actorId,
  }) {
    _records.add(
      FirefaConflictResolution(
        conflictId: conflictId,
        action: action,
        actorId: actorId,
        resolvedAt: DateTime.now().toUtc(),
      ),
    );
    notifyListeners();
  }

  bool isResolved(String conflictId) {
    return _records.any((record) => record.conflictId == conflictId);
  }
}
