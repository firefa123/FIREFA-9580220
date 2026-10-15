import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/core/auth/role_permissions.dart';
import 'package:firefa_main_app/core/navigation/app_routes.dart';

void main() {
  group('FIREFA supported roles', () {
    test('only owner and cashier roles are exposed', () {
      expect(FirefaRole.values, [FirefaRole.owner, FirefaRole.cashier]);
      expect(FirefaRole.owner.label, 'Owner');
      expect(FirefaRole.cashier.label, 'Kasir');
    });

    test('owner has access to all registered modules', () {
      for (final module in FirefaNavigation.modules) {
        expect(
          FirefaNavigation.canOpen(FirefaRole.owner, module.id),
          isTrue,
          reason: 'Owner should be able to open ${module.id}.',
        );
      }
    });

    test('cashier can use POS, orders, tables, and printer setup only', () {
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.posAccess), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.ordersView), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.tablesManage), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.printerManage), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.cashierShiftManage), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.settingsManage), isFalse);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.inventoryManage), isFalse);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.reportsView), isFalse);
    });

    test('cashier cannot access owner-only financial and customer modules', () {
      expect(FirefaNavigation.canOpen(FirefaRole.cashier, 'finance'), isFalse);
      expect(FirefaNavigation.canOpen(FirefaRole.cashier, 'customers'), isFalse);
    });

    test('printer navigation describes one cashier printer configuration', () {
      final printer = FirefaNavigation.modules.singleWhere(
        (module) => module.id == 'printers',
      );

      expect(printer.title, 'Printer Kasir');
      expect(printer.description, 'Konfigurasi printer struk kasir.');
      expect(FirefaNavigation.canOpen(FirefaRole.cashier, 'printers'), isTrue);
      expect(FirefaNavigation.canOpen(FirefaRole.owner, 'printers'), isTrue);
    });
  });
}
