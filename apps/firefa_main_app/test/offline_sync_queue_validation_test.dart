import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FirefaOfflineSyncQueue.instance.initialize();
  });

  FirefaOrder order({String id = 'order-1', String outletId = 'outlet-1'}) =>
      FirefaOrder(
        id: id,
        outletId: outletId,
        orderType: 'Take Away',
        tableId: null,
        createdAt: DateTime.utc(2026, 1, 1),
        items: const [
          FirefaOrderItem(productName: 'Coffee', quantity: 1, unitPrice: 1000),
        ],
        subtotal: 1000,
        discount: 0,
        tax: 0,
        service: 0,
        total: 1000,
      );

  test('enqueue rejects blank outlet, order ID and event type without mutation', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    final before = queue.entriesForOutlet('outlet-1').length;

    expect(
      () => queue.enqueueOrder(order(outletId: '  '), 'order.created'),
      throwsArgumentError,
    );
    expect(
      () => queue.enqueueOrder(order(id: '  '), 'order.created'),
      throwsArgumentError,
    );
    expect(
      () => queue.enqueueOrder(order(), '  '),
      throwsArgumentError,
    );

    expect(queue.entriesForOutlet('outlet-1'), hasLength(before));
    await queue.waitForPendingSave();
  });

  test('enqueue creates unique immutable identity snapshot for valid event', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    final first = queue.enqueueOrder(order(id: 'identity-order-1'), 'order.created');
    final second = queue.enqueueOrder(order(id: 'identity-order-2'), 'order.created');

    expect(first.eventId, isNot(second.eventId));
    expect(first.outletId, 'outlet-1');
    expect(first.orderId, 'identity-order-1');
    expect(first.orderSnapshot['id'], 'identity-order-1');
    expect(first.orderSnapshot['outletId'], 'outlet-1');
    expect(second.orderSnapshot['id'], 'identity-order-2');
    await queue.waitForPendingSave();

    await queue.removeEvent(first.eventId);
    await queue.removeEvent(second.eventId);
    await queue.waitForPendingSave();
  });
}
