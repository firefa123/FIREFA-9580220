import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/inventory/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy processed order marker migrates from movement ledger', () async {
    SharedPreferences.setMockInitialValues({
      'firefa_inventory_domain_v1': jsonEncode({
        'version': 1,
        'nextMovementId': 2,
        'items': [
          {'id': 'beans', 'name': 'Beans', 'unit': 'kg', 'minimumStock': 0},
        ],
        'stock': {'A::beans': 8},
        'movements': [
          {
            'id': 'INV-1',
            'outletId': 'A',
            'itemId': 'beans',
            'type': 'order_consumption',
            'quantity': 2,
            'referenceOutletId': null,
            'referenceOrderId': 'LEGACY-ORDER',
            'createdAt': '2026-10-13T00:00:00.000Z',
          },
        ],
        'processedOrderIds': ['LEGACY-ORDER'],
      }),
    });

    final store = InventoryStore();
    await store.initialize();

    expect(
      store.isOrderProcessed('LEGACY-ORDER', outletId: 'A'),
      isTrue,
    );
    expect(
      await store.consumeOrderIngredients(
        orderId: 'LEGACY-ORDER',
        outletId: 'A',
        ingredientQuantities: {'beans': 2},
      ),
      isFalse,
    );
    expect(store.stockFor('A', 'beans'), 8);
  });
}
