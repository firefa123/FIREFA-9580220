import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/core/auth/role_permissions.dart';
import 'package:firefa_main_app/features/modules/backend_client.dart';

void main() {
  const serverOutletA = 'a61d7750-dc66-48bd-895f-fc415a88bdc6';
  const serverOutletB = 'b61d7750-dc66-48bd-895f-fc415a88bdc6';
  const tenantId = 'aae7fb49-a6b3-4f26-b8a1-78edc6c56d5f';
  const userId = 'cae7fb49-a6b3-4f26-b8a1-78edc6c56d5f';

  test('outlet resolution requires explicit mapping and session authorization', () {
    expect(
      FirefaBackendConfig.resolveServerOutletId(
        localOutletId: 'outlet-001',
        mapping: const {'outlet-001': serverOutletA},
        authorizedServerOutletIds: const [serverOutletA],
      ),
      serverOutletA,
    );
    expect(
      () => FirefaBackendConfig.resolveServerOutletId(
        localOutletId: 'outlet-002',
        mapping: const {'outlet-001': serverOutletA},
        authorizedServerOutletIds: const [serverOutletA],
      ),
      throwsFormatException,
    );
    expect(
      () => FirefaBackendConfig.resolveServerOutletId(
        localOutletId: 'outlet-001',
        mapping: const {'outlet-001': serverOutletA},
        authorizedServerOutletIds: const [serverOutletB],
      ),
      throwsFormatException,
    );
    expect(
      () => FirefaBackendConfig.resolveServerOutletId(
        localOutletId: 'outlet-001',
        mapping: const {'outlet-001': 'outlet-001'},
        authorizedServerOutletIds: const ['outlet-001'],
      ),
      throwsFormatException,
    );
  });

  test('backend session accepts only owner/cashier and UUID identities', () {
    final session = FirefaBackendSession.fromJson({
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'tenantId': tenantId,
      'role': 'cashier',
      'outletIds': [serverOutletA],
      'user': {
        'id': userId,
        'email': 'cashier@example.test',
        'displayName': 'Cashier',
      },
    });
    expect(session.role, FirefaRole.cashier);
    expect(session.tenantId, tenantId);
    expect(session.outletIds, [serverOutletA]);

    expect(
      () => FirefaBackendSession.fromJson({
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'tenantId': tenantId,
        'role': 'manager',
        'outletIds': [serverOutletA],
        'user': {
          'id': userId,
          'email': 'manager@example.test',
          'displayName': 'Manager',
        },
      }),
      throwsFormatException,
    );
  });

  test('session rejects missing outlet access and duplicate outlet IDs', () {
    final base = <String, dynamic>{
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'tenantId': tenantId,
      'role': 'owner',
      'outletIds': [serverOutletA, serverOutletA],
      'user': {
        'id': userId,
        'email': 'owner@example.test',
        'displayName': 'Owner',
      },
    };
    expect(
      () => FirefaBackendSession.fromJson(base),
      throwsFormatException,
    );
    base['outletIds'] = <String>[];
    expect(
      () => FirefaBackendSession.fromJson(base),
      throwsFormatException,
    );
  });
}
