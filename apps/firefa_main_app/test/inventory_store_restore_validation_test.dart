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

    final store = FirefaInventoryStore.instance;
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
}
