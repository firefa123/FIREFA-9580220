import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('invalid snapshot does not partially restore and can be retried', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      FirefaInventoryStore.storageKey,
      jsonEncode({
        'version': 1,
        'nextId': 2,
        'items': [
          {
            'id': 'inventory-1',
            'outletId': 'outlet-a',
            'name': 'Beans',
            'unit': 'invalid-unit',
            'stock': 10,
            'minimumStock': 1,
          },
        ],
        'nextMovementId': 1,
        'movements': [],
        'nextOpnameId': 1,
        'opnames': [],
        'recipes': [],
        'processedOrderIds': [],
        'reversedOrderIds': [],
      }),
    );

    final store = FirefaInventoryStore.forTesting();
    await expectLater(store.initialize(), throwsFormatException);

    await prefs.setString(
      FirefaInventoryStore.storageKey,
      jsonEncode({
        'version': 1,
        'nextId': 1,
        'items': [],
        'nextMovementId': 1,
        'movements': [],
        'nextOpnameId': 1,
        'opnames': [],
        'recipes': [],
        'processedOrderIds': [],
        'reversedOrderIds': [],
      }),
    );

    await expectLater(store.initialize(), completes);
    expect(store.forOutlet('outlet-a'), isEmpty);
  });
  test('restore rejects stock movement type and direction mismatches', () async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> snapshot({
      required String type,
      required int before,
      required int after,
    }) => {
      'version': 1,
      'nextId': 2,
      'items': [
        {
          'id': 'inventory-1',
          'outletId': 'outlet-a',
          'name': 'Beans',
          'unit': 'kg',
          'stock': after,
          'minimumStock': 1,
        },
      ],
      'nextMovementId': 2,
      'movements': [
        {
          'id': 'movement-1',
          'outletId': 'outlet-a',
          'itemId': 'inventory-1',
          'itemName': 'Beans',
          'type': type,
          'before': before,
          'after': after,
          'note': 'restore test',
          'timestamp': '2026-10-13T00:00:00.000Z',
        },
      ],
      'nextOpnameId': 1,
      'opnames': [],
      'recipes': [],
      'processedOrderIds': [],
      'reversedOrderIds': [],
    };

    final orphanMovement = snapshot(type: 'in', before: 2, after: 3);
    (orphanMovement['movements'] as List).single['itemId'] = 'missing-item';
    final orphanRecipe = snapshot(type: 'in', before: 2, after: 3);
    orphanRecipe['recipes'] = [
      {
        'outletId': 'outlet-a',
        'menuId': 'menu-coffee',
        'ingredientId': 'missing-item',
        'quantity': 1,
      },
    ];
    final movementSequenceCollision = snapshot(type: 'in', before: 2, after: 3)
      ..['nextMovementId'] = 1;
    final opnameSequenceCollision = snapshot(type: 'in', before: 2, after: 3)
      ..['opnames'] = [
        {
          'id': 'opname-1',
          'outletId': 'outlet-a',
          'itemId': 'inventory-1',
          'itemName': 'Beans',
          'systemStock': 2,
          'physicalStock': 3,
          'note': 'audit',
          'createdAt': '2026-10-13T00:00:00.000Z',
          'status': 'pending',
          'resolvedAt': null,
        },
      ];

    final store = FirefaInventoryStore.forTesting();
    for (final invalid in [
      snapshot(type: 'unknown', before: 2, after: 3),
      snapshot(type: 'in', before: 5, after: 3),
      snapshot(type: 'out', before: 2, after: 4),
      snapshot(type: 'correction', before: 3, after: 3),
      orphanMovement,
      orphanRecipe,
      movementSequenceCollision,
      opnameSequenceCollision,
    ]) {
      await prefs.setString(FirefaInventoryStore.storageKey, jsonEncode(invalid));
      await expectLater(store.initialize(), throwsFormatException);
    }

    await prefs.setString(
      FirefaInventoryStore.storageKey,
      jsonEncode(snapshot(type: 'in', before: 2, after: 3)),
    );
    await expectLater(store.initialize(), completes);
    expect(store.forOutlet('outlet-a').single.stock, 3);
  });

}
