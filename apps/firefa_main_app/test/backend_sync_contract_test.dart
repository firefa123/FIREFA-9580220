import 'package:flutter_test/flutter_test.dart';

import 'package:firefa_main_app/features/modules/backend_client.dart';

void main() {
  const deviceId = '7a2aeb3a-4b76-4e51-8c51-3cb4f8a4c2d0';
  const serverOutletId = '2b6b7b60-8b90-4a56-92b0-9b6e0d1f3a10';

  Map<String, dynamic> event({
    String eventType = 'order.created',
    String outletId = 'outlet-001',
    String orderId = 'ORD-1001',
  }) => {
    'eventId': 'evt-0123456789abcdef0123456789abcdef-1',
    'outletId': outletId,
    'orderId': orderId,
    'eventType': eventType,
    'createdAt': '2026-10-17T10:00:00.000Z',
    'orderSnapshot': {
      'id': orderId,
      'outletId': outletId,
      'status': 'confirmed',
      'items': [
        {'productName': 'Coffee', 'quantity': 1, 'unitPrice': 1000},
      ],
      'subtotal': 1000,
      'discount': 0,
      'tax': 0,
      'service': 0,
      'total': 1000,
    },
  };

  test('sync payload maps local outlet and preserves event idempotency key', () {
    final payload = FirefaBackendConfig.buildSyncPayload(
      event: event(),
      deviceId: deviceId,
      mapping: const {'outlet-001': serverOutletId},
      authorizedServerOutletIds: const [serverOutletId],
    );

    expect(payload['schemaVersion'], 1);
    expect(payload['eventId'], 'evt-0123456789abcdef0123456789abcdef-1');
    expect(payload['deviceId'], deviceId);
    expect(payload['outletId'], serverOutletId);
    expect(payload['orderId'], 'ORD-1001');
    expect(payload['orderSnapshot']['outletId'], serverOutletId);
  });

  test('order update requires an expected server version', () {
    expect(
      () => FirefaBackendConfig.buildSyncPayload(
        event: event(eventType: 'order.updated'),
        deviceId: deviceId,
        mapping: const {'outlet-001': serverOutletId},
        authorizedServerOutletIds: const [serverOutletId],
      ),
      throwsFormatException,
    );

    final payload = FirefaBackendConfig.buildSyncPayload(
      event: event(eventType: 'order.updated'),
      deviceId: deviceId,
      mapping: const {'outlet-001': serverOutletId},
      authorizedServerOutletIds: const [serverOutletId],
      expectedServerVersion: 4,
    );
    expect(payload['expectedServerVersion'], 4);
  });

  test('sync payload rejects an outlet outside authenticated scope', () {
    expect(
      () => FirefaBackendConfig.buildSyncPayload(
        event: event(),
        deviceId: deviceId,
        mapping: const {'outlet-001': serverOutletId},
        authorizedServerOutletIds: const [],
      ),
      throwsFormatException,
    );
  });

  test('sync payload rejects identity mismatch in the order snapshot', () {
    final invalid = event();
    (invalid['orderSnapshot'] as Map<String, dynamic>)['id'] = 'ORD-OTHER';
    expect(
      () => FirefaBackendConfig.buildSyncPayload(
        event: invalid,
        deviceId: deviceId,
        mapping: const {'outlet-001': serverOutletId},
        authorizedServerOutletIds: const [serverOutletId],
      ),
      throwsFormatException,
    );
  });
}
