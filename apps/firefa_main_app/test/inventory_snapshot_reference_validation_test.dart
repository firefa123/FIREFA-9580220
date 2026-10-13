import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/inventory/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restore rejects stock keys that reference missing catalog items', () async {
    SharedPreferences.setMockInitialValues({
      'firefa_inventory_domain_v1': jsonEncode({
        'version': 1,
        'nextMovementId': 1,
        'items': [
          {'id': 'beans', 'name': 'Beans', 'unit': 'kg', 'minimumStock': 0},
        ],
        'stock': {'A::ghost': 4},
        'movements': [],
        'processedOrderIds': [],
      }),
    });

    final store = InventoryStore();
    await expectLater(store.initialize(), throwsFormatException);
    expect(() => store.stockFor('A', 'beans'), throwsStateError);
  });

  test('restore rejects movement entries that reference missing catalog items', () async {
    SharedPreferences.setMockInitialValues({
      'firefa_inventory_domain_v1': jsonEncode({
        'version': 1,
        'nextMovementId': 2,
        'items': [
          {'id': 'beans', 'name': 'Beans', 'unit': 'kg', 'minimumStock': 0},
        ],
        'stock': {'A::beans': 4},
        'movements': [
          {
            'id': 'INV-1',
            'outletId': 'A',
            'itemId': 'ghost',
            'type': 'stock_in',
            'quantity': 4,
            'referenceOutletId': null,
            'referenceOrderId': null,
            'createdAt': '2026-10-13T00:00:00.000Z',
          },
        ],
        'processedOrderIds': [],
      }),
    });

    final store = InventoryStore();
    await expectLater(store.initialize(), throwsFormatException);
    expect(() => store.items, throwsStateError);
  });
}
