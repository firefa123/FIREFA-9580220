import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/inventory/inventory_controller.dart';
import 'package:firefa_main_app/features/inventory/inventory_item_model.dart';

InventoryItem item(String id, {
  String name = 'Coffee',
  double stock = 10,
  String unit = 'pcs',
}) => InventoryItem(id: id, name: name, stock: stock, unit: unit);

void main() {
  group('InventoryController', () {
    test('adds normalized item and finds by ID', () {
      final controller = InventoryController()..addItem(item(' SKU-1 ', name: ' Coffee '));
      expect(controller.findById('SKU-1')?.name, 'Coffee');
      expect(controller.totalItems, 1);
    });

    test('rejects duplicate IDs', () {
      final controller = InventoryController()..addItem(item('SKU-1'));
      expect(() => controller.addItem(item(' SKU-1 ')), throwsArgumentError);
    });

    test('rejects invalid fields and stock', () {
      final controller = InventoryController();
      expect(() => controller.addItem(item(' ')), throwsArgumentError);
      expect(() => controller.addItem(item('SKU-1', name: ' ')), throwsArgumentError);
      expect(() => controller.addItem(item('SKU-1', unit: ' ')), throwsArgumentError);
      expect(() => controller.addItem(item('SKU-1', stock: -1)), throwsArgumentError);
      expect(() => controller.addItem(item('SKU-1', stock: double.nan)), throwsArgumentError);
    });

    test('updates item and rejects ID collision', () {
      final controller = InventoryController()
        ..addItem(item('SKU-1'))
        ..addItem(item('SKU-2', name: 'Tea'));
      expect(controller.updateItem('SKU-1', item('SKU-1', name: 'Coffee Beans')), isTrue);
      expect(controller.findById('SKU-1')?.name, 'Coffee Beans');
      expect(() => controller.updateItem('SKU-1', item('SKU-2')), throwsArgumentError);
      expect(controller.updateItem('missing', item('missing')), isFalse);
    });

    test('removes items and handles missing IDs', () {
      final controller = InventoryController()..addItem(item('SKU-1'));
      expect(controller.removeItem('SKU-1'), isTrue);
      expect(controller.removeItem('SKU-1'), isFalse);
      expect(controller.totalItems, 0);
    });

    test('searches by ID, name, and unit without case sensitivity', () {
      final controller = InventoryController()
        ..addItem(item('SKU-1', name: 'Coffee Beans', unit: 'Bag'))
        ..addItem(item('SKU-2', name: 'Tea', unit: 'Box'));
      expect(controller.search('COFFEE').single.id, 'SKU-1');
      expect(controller.search('sku-2').single.name, 'Tea');
      expect(controller.search('box').single.id, 'SKU-2');
      expect(controller.search(' ').length, 2);
    });

    test('identifies low stock items', () {
      final controller = InventoryController()
        ..addItem(item('SKU-1', stock: 5))
        ..addItem(item('SKU-2', stock: 5.1));
      expect(controller.lowStockItems.map((value) => value.id), ['SKU-1']);
    });

    test('exposes an unmodifiable list', () {
      final controller = InventoryController()..addItem(item('SKU-1'));
      expect(() => controller.items.add(item('SKU-2')), throwsUnsupportedError);
    });
  });
}
