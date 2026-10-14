import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/cashier_shift_page.dart';

void main() {
  group('FirefaCashierShift', () {
    test('calculates expected cash and shortage or surplus', () {
      final shift = FirefaCashierShift(
        id: 'SHIFT-1',
        outletId: 'outlet-001',
        cashierName: 'Kasir',
        openedAt: DateTime(2026, 10, 14, 9),
        openingCash: 200000,
        cashSales: 750000,
        cashIn: 50000,
        cashOut: 25000,
        closedAt: DateTime(2026, 10, 14, 17),
        countedCash: 970000,
      );

      expect(shift.expectedCash, 975000);
      expect(shift.difference, -5000);
      expect(shift.isOpen, isFalse);
    });

    test('serializes and restores an open shift', () {
      final openedAt = DateTime(2026, 10, 14, 9);
      final shift = FirefaCashierShift(
        id: 'SHIFT-2',
        outletId: 'outlet-001',
        cashierName: 'Kasir',
        openedAt: openedAt,
        openingCash: 100000,
      );

      final restored = FirefaCashierShift.fromJson(shift.toJson());

      expect(restored.id, shift.id);
      expect(restored.outletId, shift.outletId);
      expect(restored.openingCash, 100000);
      expect(restored.isOpen, isTrue);
      expect(restored.expectedCash, 100000);
      expect(restored.difference, isNull);
    });
  });
}
