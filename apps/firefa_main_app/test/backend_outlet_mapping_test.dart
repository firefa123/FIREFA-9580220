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
}
