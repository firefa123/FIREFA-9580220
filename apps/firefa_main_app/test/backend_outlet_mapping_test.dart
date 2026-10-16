import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/backend_client.dart';

void main() {
  group('FirefaBackendConfig.resolveServerOutletId', () {
    const mapping = {
      'outlet-001': '11111111-1111-4111-8111-111111111111',
      'outlet-002': '22222222-2222-4222-8222-222222222222',
    };

    test('maps a local outlet ID to an authorized server UUID', () {
      expect(
        FirefaBackendConfig.resolveServerOutletId(
          localOutletId: 'outlet-001',
          mapping: mapping,
          authorizedServerOutletIds: const [
            '11111111-1111-4111-8111-111111111111',
          ],
        ),
        '11111111-1111-4111-8111-111111111111',
      );
    });

    test('fails closed when the local outlet has no mapping', () {
      expect(
        () => FirefaBackendConfig.resolveServerOutletId(
          localOutletId: 'outlet-999',
          mapping: mapping,
          authorizedServerOutletIds: mapping.values,
        ),
        throwsFormatException,
      );
    });

    test('rejects a mapped outlet not authorized for the session', () {
      expect(
        () => FirefaBackendConfig.resolveServerOutletId(
          localOutletId: 'outlet-002',
          mapping: mapping,
          authorizedServerOutletIds: const [
            '11111111-1111-4111-8111-111111111111',
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects an empty local outlet ID', () {
      expect(
        () => FirefaBackendConfig.resolveServerOutletId(
          localOutletId: ' ',
          mapping: mapping,
          authorizedServerOutletIds: mapping.values,
        ),
        throwsArgumentError,
      );
    });
  });

  group('FirefaBackendConfig.buildSyncPayload', () {
    const mapping = {
      'outlet-001': '11111111-1111-4111-8111-111111111111',
    };
    const deviceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

    Map<String, dynamic> event({
      String eventType = 'order.created',
      String outletId = 'outlet-001',
      String snapshotOutletId = 'outlet-001',
    }) => {
      'eventId': 'evt-1234567890123456',
      'outletId': outletId,
      'orderId': 'order-1001',
      'eventType': eventType,
      'createdAt': '2026-10-16T03:00:00.000Z',
      'orderSnapshot': {
        'id': 'order-1001',
        'outletId': snapshotOutletId,
        'items': const [],
      },
    };

    test('builds backend contract with server outlet ID', () {
      final payload = FirefaBackendConfig.buildSyncPayload(
        event: event(),
        deviceId: deviceId,
        mapping: mapping,
        authorizedServerOutletIds: mapping.values,
      );

      expect(payload['schemaVersion'], 1);
      expect(payload['deviceId'], deviceId);
      expect(payload['outletId'], mapping['outlet-001']);
      expect((payload['orderSnapshot'] as Map)['outletId'], mapping['outlet-001']);
      expect(payload['eventId'], 'evt-1234567890123456');
    });

    test('does not build a payload for an unmapped outlet', () {
      expect(
        () => FirefaBackendConfig.buildSyncPayload(
          event: event(outletId: 'outlet-missing', snapshotOutletId: 'outlet-missing'),
          deviceId: deviceId,
          mapping: mapping,
          authorizedServerOutletIds: mapping.values,
        ),
        throwsFormatException,
      );
    });

    test('rejects an inconsistent order snapshot', () {
      expect(
        () => FirefaBackendConfig.buildSyncPayload(
          event: event(snapshotOutletId: 'outlet-other'),
          deviceId: deviceId,
          mapping: mapping,
          authorizedServerOutletIds: mapping.values,
        ),
        throwsFormatException,
      );
    });

    test('requires expected server version for order updates', () {
      expect(
        () => FirefaBackendConfig.buildSyncPayload(
          event: event(eventType: 'order.updated'),
          deviceId: deviceId,
          mapping: mapping,
          authorizedServerOutletIds: mapping.values,
        ),
        throwsFormatException,
      );
    });
  });

}
