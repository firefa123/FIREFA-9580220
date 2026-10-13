import 'inventory_audit_store.dart';
import 'inventory_hybrid_sync.dart';

/// Read-only summary provider for owner dashboard inventory monitoring.
/// Keeps dashboard integration separated from inventory mutation logic.
class FirefaInventoryDashboardIntegration {
  const FirefaInventoryDashboardIntegration();

  InventoryDashboardSummary buildSummary({
    required List<InventoryHybridSyncRecord> records,
    required List<InventoryAuditRecord> audits,
  }) {
    final conflicts = records.where(
      (item) => item.status.name == 'conflict',
    ).length;

    return InventoryDashboardSummary(
      totalTrackedItems: records.length,
      conflictItems: conflicts,
      latestAudit: audits.isEmpty ? null : audits.last,
    );
  }
}

class InventoryDashboardSummary {
  final int totalTrackedItems;
  final int conflictItems;
  final InventoryAuditRecord? latestAudit;

  const InventoryDashboardSummary({
    required this.totalTrackedItems,
    required this.conflictItems,
    required this.latestAudit,
  });
}
