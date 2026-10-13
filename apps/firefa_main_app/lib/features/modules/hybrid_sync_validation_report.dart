/// Validation report for FIREFA hybrid sync hardening.
/// This module provides a safe summary layer and does not mutate transactions.
class FirefaHybridSyncValidationReport {
  final int processedEvents;
  final int successfulSyncs;
  final int failedSyncs;
  final int conflictsDetected;
  final int conflictsResolved;

  const FirefaHybridSyncValidationReport({
    required this.processedEvents,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.conflictsDetected,
    required this.conflictsResolved,
  });

  double get successRate => processedEvents == 0
      ? 0
      : successfulSyncs / processedEvents;

  bool get healthy =>
      failedSyncs == 0 && conflictsDetected == conflictsResolved;

  Map<String, dynamic> toJson() => {
        'processedEvents': processedEvents,
        'successfulSyncs': successfulSyncs,
        'failedSyncs': failedSyncs,
        'conflictsDetected': conflictsDetected,
        'conflictsResolved': conflictsResolved,
        'successRate': successRate,
        'healthy': healthy,
      };
}
