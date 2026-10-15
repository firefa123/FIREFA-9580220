import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/core/auth/role_permissions.dart';
import 'package:firefa_main_app/core/models/menu_item.dart';
import 'package:firefa_main_app/core/models/outlet_model.dart';
import 'package:firefa_main_app/core/repositories/menu_repository.dart';
import 'package:firefa_main_app/core/repositories/outlet_repository.dart';
import 'package:firefa_main_app/core/storage/audit_trail_store.dart';
import 'package:firefa_main_app/core/storage/document_number_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('role permissions expose owner and cashier only', () {
    expect(FirefaRole.values, [FirefaRole.owner, FirefaRole.cashier]);
    expect(FirefaAccess.can(FirefaRole.owner, FirefaPermission.settingsManage), isTrue);
    expect(FirefaAccess.can(FirefaRole.owner, FirefaPermission.inventoryManage), isTrue);
    expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.posAccess), isTrue);
    expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.ordersView), isTrue);
    expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.printerManage), isTrue);
    expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.settingsManage), isFalse);
    expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.inventoryManage), isFalse);
    expect(FirefaAccess.can(FirefaRole.cashier, FirefaPermission.reportsView), isFalse);
  });

  test('outlet repository persists, updates and filters active outlets', () async {
    final repository = OutletRepository();
    await repository.initialize();
    expect(repository.getOutlets(), hasLength(2));
    await repository.save(const OutletModel(
      id: 'outlet-003',
      name: 'Outlet Baru',
      address: 'Jalan Test',
      active: true,
      tenantId: 'tenant-1',
    ));
    expect(repository.findById('outlet-003')?.tenantId, 'tenant-1');
    await repository.save(const OutletModel(
      id: 'outlet-003',
      name: 'Outlet Baru',
      address: 'Jalan Test',
      active: false,
    ));
    expect(repository.getOutlets(activeOnly: true), hasLength(2));
    final restored = OutletRepository();
    await restored.initialize();
    expect(restored.findById('outlet-003')?.active, isFalse);
  });

  test('product repository round-trips variants and rejects duplicate barcode', () async {
    final repository = MenuRepository();
    await repository.initialize();
    await repository.save(const MenuItem(
      id: 'coffee',
      name: 'Kopi Susu',
      category: 'Minuman',
      price: 18000,
      available: true,
      outletId: 'outlet-001',
      sku: 'COF-01',
      barcode: '12345',
      variants: [
        ProductVariant(
          id: 'coffee-large-ice',
          name: 'Large / Ice',
          price: 22000,
          sku: 'COF-01-LI',
          barcode: '123456',
        ),
      ],
    ));
    final restored = MenuRepository();
    await restored.initialize();
    expect(restored.findById('coffee')?.variants.single.name, 'Large / Ice');
    await expectLater(
      repository.save(const MenuItem(
        id: 'other',
        name: 'Kopi Lain',
        category: 'Minuman',
        price: 10000,
        available: true,
        outletId: 'outlet-001',
        barcode: '12345',
      )),
      throwsStateError,
    );
  });

  test('document numbers are unique per outlet, type and date', () async {
    final store = FirefaDocumentNumberStore();
    final date = DateTime(2026, 10, 14);
    final first = await store.next(
      outletId: 'outlet-001',
      documentType: 'transaction',
      date: date,
    );
    final second = await store.next(
      outletId: 'outlet-001',
      documentType: 'transaction',
      date: date,
    );
    final otherOutlet = await store.next(
      outletId: 'outlet-002',
      documentType: 'transaction',
      date: date,
    );
    expect(first, 'TRX-20261014-000001');
    expect(second, 'TRX-20261014-000002');
    expect(otherOutlet, 'TRX-20261014-000001');
  });

  test('audit trail stores actor, outlet and details and can filter', () async {
    final store = FirefaAuditTrailStore();
    await store.append(
      action: 'created',
      entityType: 'product',
      entityId: 'coffee',
      actorId: 'owner-1',
      outletId: 'outlet-001',
      details: const {'name': 'Kopi Susu'},
      timestamp: DateTime(2026, 10, 14),
    );
    await store.append(
      action: 'updated',
      entityType: 'product',
      entityId: 'coffee',
      actorId: 'owner-1',
      outletId: 'outlet-002',
    );
    final entries = await store.read(outletId: 'outlet-001');
    expect(entries, hasLength(1));
    expect(entries.single.details['name'], 'Kopi Susu');
    expect(entries.single.actorId, 'owner-1');
  });
}
