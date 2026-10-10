/// Validation checklist model for FIREFA hybrid offline-first flow.
/// Keeps verification scenarios documented in code without touching UI.
class FirefaSyncValidationScenario {
  final String name;
  final String expectedResult;

  const FirefaSyncValidationScenario({
    required this.name,
    required this.expectedResult,
  });
}

const firefaHybridSyncValidationScenarios = [
  FirefaSyncValidationScenario(
    name: 'Offline order then reconnect',
    expectedResult: 'Order stays in outbox and syncs once connection returns',
  ),
  FirefaSyncValidationScenario(
    name: 'Duplicate payment event',
    expectedResult: 'Payment conflict requires review and is not duplicated',
  ),
  FirefaSyncValidationScenario(
    name: 'Inventory mismatch',
    expectedResult: 'Stock divergence enters conflict workflow',
  ),
  FirefaSyncValidationScenario(
    name: 'Backup restore recovery',
    expectedResult: 'Restored local data can continue hybrid synchronization',
  ),
];
