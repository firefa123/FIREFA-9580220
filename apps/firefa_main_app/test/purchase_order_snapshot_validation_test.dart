import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/purchase_order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('purchase order restore rejects duplicate IDs and inconsistent receipts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = FirefaPurchaseOrderStore.instance;

    Map<String, dynamic> order({
      String id = 'po-1',
      int quantity = 5,
      int receivedQuantity = 0,
      String status = 'ordered',
      List<Map<String, dynamic>> receipts = const [],
    }) => {
      'id': id,
      'outletId': 'outlet-1',
      'supplierId': 'supplier-1',
      'supplierName': 'Supplier',
      'itemId': 'item-1',
      'itemName': 'Coffee',
      'unit': 'kg',
      'quantity': quantity,
      'unitCost': 1000,
      'note': '',
      'status': status,
      'createdAt': '2026-10-13T00:00:00.000Z',
      'receivedAt': null,
      'cancelledAt': null,
      'followUpNote': '',
      'followUpDate': null,
      'followUpContactedAt': null,
      'receivedQuantity': receivedQuantity,
      'receipts': receipts,
    };

    final invalidSnapshots = <Map<String, dynamic>>[
      {
        'version': 1,
        'nextId': 2,
        'orders': [order(), order()],
      },
      {
        'version': 1,
        'nextId': 2,
        'orders': [
          order(
            receivedQuantity: 2,
            status: 'partial',
            receipts: [
              {
                'id': 'po-1-receipt-1',
                'quantity': 1,
                'receivedAt': '2026-10-13T00:00:00.000Z',
              },
            ],
          ),
        ],
      },
      {
        'version': 1,
        'nextId': 1,
        'orders': [order()],
      },
    ];

    for (final snapshot in invalidSnapshots) {
      await prefs.setString(
        FirefaPurchaseOrderStore.storageKey,
        jsonEncode(snapshot),
      );
      await expectLater(store.initialize(), throwsFormatException);
    }
  });
}
