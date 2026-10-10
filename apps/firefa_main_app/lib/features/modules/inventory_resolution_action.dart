enum InventoryResolutionAction {
  useLocalStock,
  useServerStock,
  manualAdjustment,
}

class InventoryResolutionAudit {
  final String itemId;
  final InventoryResolutionAction action;
  final String resolvedBy;
  final DateTime resolvedAt;

  const InventoryResolutionAudit({
    required this.itemId,
    required this.action,
    required this.resolvedBy,
    required this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'action': action.name,
        'resolvedBy': resolvedBy,
        'resolvedAt': resolvedAt.toUtc().toIso8601String(),
      };
}

/// Applies inventory conflict decisions as a controlled command.
/// Actual stock mutation remains handled by inventory domain services.
class InventoryResolutionActionHandler {
  const InventoryResolutionActionHandler();

  InventoryResolutionAudit resolve({
    required String itemId,
    required InventoryResolutionAction action,
    required String userId,
  }) {
    return InventoryResolutionAudit(
      itemId: itemId,
      action: action,
      resolvedBy: userId,
      resolvedAt: DateTime.now(),
    );
  }
}
