import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/table_store.dart';

void main() {
  test('table JSON round trip retains outlet and occupancy', () {
    const table = FirefaTable(
      id: 'table-1', outletId: 'outlet-a', name: 'Meja 01', occupied: true,
    );
    final restored = FirefaTable.fromJson(table.toJson());
    expect(restored.id, 'table-1');
    expect(restored.outletId, 'outlet-a');
    expect(restored.name, 'Meja 01');
    expect(restored.occupied, true);
  });

  test('occupancy update does not alter identity', () {
    const table = FirefaTable(
      id: 'table-1', outletId: 'outlet-a', name: 'Meja 01', occupied: false,
    );
    final changed = table.copyWith(occupied: true);
    expect(changed.occupied, true);
    expect(changed.id, table.id);
    expect(changed.outletId, table.outletId);
    expect(changed.name, table.name);
    expect(table.occupied, false);
  });

  test('renaming does not change occupancy or outlet', () {
    const table = FirefaTable(
      id: 'table-1', outletId: 'outlet-a', name: 'Meja 01', occupied: true,
    );
    final renamed = table.copyWith(name: 'VIP 01');
    expect(renamed.name, 'VIP 01');
    expect(renamed.occupied, true);
    expect(renamed.outletId, 'outlet-a');
  });
}
