import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/dashboard/widgets/sync_status_card.dart';
import 'package:firefa_main_app/features/modules/backend_client.dart';
import 'package:firefa_main_app/features/modules/conflict_store.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'default sync status card uses HTTP transport and keeps local event pending without config',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final queue = FirefaOfflineSyncQueue.instance;
      await queue.initialize();
      await FirefaConflictStore.instance.initialize();

      final order = FirefaOrder(
        id: 'SYNC-TRANSPORT-WIRING',
        outletId: 'outlet-001',
        orderType: 'Take Away',
        tableId: null,
        createdAt: DateTime.utc(2026, 10, 17),
        items: const [
          FirefaOrderItem(
            productName: 'Test menu',
            quantity: 1,
            unitPrice: 1000,
          ),
        ],
        subtotal: 1000,
        discount: 0,
        tax: 0,
        service: 0,
        total: 1000,
      );
      final entry = queue.enqueueOrder(order, 'order.created');
      await queue.waitForPendingSave();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusCard(outletId: 'outlet-001'),
          ),
        ),
      );
      await tester.tap(find.text('Coba sinkronisasi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(entry.status, FirefaSyncStatus.pending);
      expect(entry.attempts, 1);
      expect(find.textContaining('Backend belum mengonfirmasi'), findsOneWidget);
      expect(find.textContaining('Transport HTTP sudah tersedia'), findsOneWidget);

      await queue.removeEvent(entry.eventId);
      await queue.waitForPendingSave();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: FirefaBackendConfig.isConfigured
        ? 'Requires the CI environment with no provisioned cloud endpoint.'
        : false,
  );
}
