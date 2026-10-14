import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/super_admin/platform_analytics_controller.dart';

void main() {
  group('PlatformAnalyticsController', () {
    test('counts unique non-empty platform identifiers', () {
      final summary = PlatformAnalyticsController(
        tenantIds: const ['tenant-1', 'tenant-2', ' tenant-1 ', '', '  '],
        outletIds: const ['outlet-1', 'outlet-2', 'outlet-2'],
        userIds: const ['user-1', 'user-2', 'user-3', 'user-1'],
        totalTransactions: 42,
      ).getSummary();

      expect(summary.totalTenants, 2);
      expect(summary.totalOutlets, 2);
      expect(summary.totalUsers, 3);
      expect(summary.totalTransactions, 42);
    });

    test('returns zero counts when no data source is supplied', () {
      final summary = PlatformAnalyticsController().getSummary();

      expect(summary.totalTenants, 0);
      expect(summary.totalOutlets, 0);
      expect(summary.totalUsers, 0);
      expect(summary.totalTransactions, 0);
    });

    test('rejects negative transaction totals', () {
      expect(
        () => PlatformAnalyticsController(totalTransactions: -1),
        throwsArgumentError,
      );
    });
  });
}
