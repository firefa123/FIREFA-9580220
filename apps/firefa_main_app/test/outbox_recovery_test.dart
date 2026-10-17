import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup recovers interrupted outbox sends and persists pending state', () async {
    final interruptedEntry = <String, dynamic>{
      'eventId': 'evt-restart-recovery-1',
      'outletId': 'restart-outlet',
      'orderId': 'ORD-1001',
      'eventType': 'order.created',
      'createdAt': '2026-10-12T08:00:00.000Z',
      'orderSnapshot': <String, dynamic>{
        'id': 'ORD-1001',
        'outletId': 'restart-outlet',
        'orderType': 'Take Away',
        'tableId': null,
        'createdAt': '2026-10-12T08:00:00.000Z',
        'items': [
          {
            'productName': 'Coffee',
            'quantity': 1,
            'unitPrice': 1000,
            'details': '',
          },
        ],
        'subtotal': 1000,
        'discount': 0,
        'tax': 0,
        'service': 0,
        'total': 1000,
        'status': 'draft',
        'paymentStatus': 'unpaid',
      },
      'status': 'syncing',
      'attempts': 2,
      'nextAttemptAt': null,
    };
    SharedPreferences.setMockInitialValues({
      'firefa_sync_outbox_v1': jsonEncode({
        'version': 1,
        'nextSequence': 2,
        'entries': [interruptedEntry],
      }),
    });

    final queue = FirefaOfflineSyncQueue.instance;
    await queue.initialize();

    final recovered = queue.findEvent('evt-restart-recovery-1');
    expect(recovered, isNotNull);
    expect(recovered!.status, FirefaSyncStatus.pending);
    expect(recovered.attempts, 2);
    expect(recovered.nextAttemptAt, isNull);

    // Recovery must be durable before initialize completes, not merely an
    // in-memory status change that would be lost on another restart.
    final prefs = await SharedPreferences.getInstance();
    final saved = Map<String, dynamic>.from(
      jsonDecode(prefs.getString('firefa_sync_outbox_v1')!) as Map,
    );
    final savedEntry = Map<String, dynamic>.from(
      (saved['entries'] as List).single as Map,
    );
    expect(savedEntry['status'], FirefaSyncStatus.pending.name);
    expect(savedEntry['attempts'], 2);
    expect(savedEntry['nextAttemptAt'], isNull);
  });
}
