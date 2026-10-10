import 'conflict_management.dart';

/// Resolution policy layer. This module decides how a conflict should be
/// handled but does not directly overwrite orders, payments, or inventory.
/// The caller remains responsible for applying a reviewed decision.
class FirefaConflictResolutionEngine {
  const FirefaConflictResolutionEngine();

  FirefaConflictResolutionPlan createPlan(FirefaSyncConflict conflict) {
    switch (conflict.kind) {
      case FirefaConflictKind.duplicatePayment:
      case FirefaConflictKind.inventoryDivergence:
        return FirefaConflictResolutionPlan(
          conflict: conflict,
          options: const [
            FirefaConflictAction.manualReview,
          ],
          recommended: FirefaConflictAction.manualReview,
        );
      case FirefaConflictKind.concurrentEdit:
      case FirefaConflictKind.staleServerVersion:
      case FirefaConflictKind.invalidServerResponse:
        return FirefaConflictResolutionPlan(
          conflict: conflict,
          options: const [
            FirefaConflictAction.keepLocal,
            FirefaConflictAction.acceptServer,
            FirefaConflictAction.manualReview,
          ],
          recommended: FirefaConflictAction.manualReview,
        );
    }
  }
}

class FirefaConflictResolutionPlan {
  final FirefaSyncConflict conflict;
  final List<FirefaConflictAction> options;
  final FirefaConflictAction recommended;

  const FirefaConflictResolutionPlan({
    required this.conflict,
    required this.options,
    required this.recommended,
  });
}
