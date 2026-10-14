import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/core/auth/role_permissions.dart';
import 'package:firefa_main_app/core/navigation/app_routes.dart';

void main() {
  group('FIREFA system roles', () {
    test('only owner and cashier are available', () {
      expect(
        FirefaRole.values,
        [FirefaRole.owner, FirefaRole.cashier],
      );
      expect(FirefaRole.owner.label, 'Owner');
      expect(FirefaRole.cashier.label, 'Cashier');
    });

    test('cashier can use POS, orders, tables, and printer setup only', () {
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.posAccess), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.ordersView), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.tablesManage), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.printerManage), isTrue);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.settingsManage), isFalse);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.inventoryManage), isFalse);
      expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.reportsView), isFalse);
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
