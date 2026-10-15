import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/finance_store.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/purchase_order_store.dart';
import 'package:firefa_main_app/features/modules/supplier_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PO receipts create payable once and partial payments cannot exceed balance', () async {
    SharedPreferences.setMockInitialValues({});
    final inventory = FirefaInventoryStore.instance;
    final suppliers = FirefaSupplierStore.instance;
    final orders = FirefaPurchaseOrderStore.instance;
    final finance = FirefaFinanceStore.instance;
    await inventory.initialize();
    await suppliers.initialize();
    await orders.initialize();
    await finance.initialize();
    const outlet = 'STAGE5-PAYABLE';
    expect(inventory.add(outletId: outlet, name: 'Beans', unit: 'kg', stock: 2, minimumStock: 0), isTrue);
    final item = inventory.forOutlet(outlet).single;
    expect(suppliers.add(outletId: outlet, name: 'Supplier payable test', contact: '', phone: '', address: ''), isTrue);
    final supplier = suppliers.forOutlet(outlet).single;
    expect(orders.create(outletId: outlet, supplierId: supplier.id, itemId: item.id, quantity: 5, unitCost: 12000, note: ''), isTrue);
    final po = orders.forOutlet(outlet).single;
    expect(await orders.receive(outletId: outlet, orderId: po.id, quantity: 2), isTrue);
    expect(await finance.syncPurchaseReceipts(outlet), 1);
    expect(await finance.syncPurchaseReceipts(outlet), 0);
    var payable = finance.payablesForOutlet(outlet).single;
    expect(payable.amount, 24000);
    expect(payable.outstanding, 24000);
    expect(finance.recordPayablePayment(outletId: outlet, payableId: payable.id, amount: 10000, method: 'Transfer'), isTrue);
    expect(finance.recordPayablePayment(outletId: outlet, payableId: payable.id, amount: 15000, method: 'Cash'), isFalse);
    await finance.waitForPendingSave();
    payable = finance.payablesForOutlet(outlet).single;
    expect(payable.paidAmount, 10000);
    expect(payable.outstanding, 14000);
    expect(payable.status, 'partial');
  });

  test('expenses, consignment, return and settlement persist as separate ledgers', () async {
    SharedPreferences.setMockInitialValues({});
    final inventory = FirefaInventoryStore.instance;
    final suppliers = FirefaSupplierStore.instance;
    final finance = FirefaFinanceStore.instance;
    await inventory.initialize();
    await suppliers.initialize();
    await finance.initialize();
    const outlet = 'STAGE5-CONSIGNMENT';
    expect(inventory.add(outletId: outlet, name: 'Bottle', unit: 'pcs', stock: 3, minimumStock: 0), isTrue);
    final item = inventory.forOutlet(outlet).single;
    expect(suppliers.add(outletId: outlet, name: 'Supplier consignment test', contact: '', phone: '', address: ''), isTrue);
    final supplier = suppliers.forOutlet(outlet).single;
    expect(await finance.receiveConsignment(outletId: outlet, supplierId: supplier.id, itemId: item.id, quantity: 8, unitCost: 5000), isTrue);
    var batch = finance.consignmentsForOutlet(outlet).single;
    expect(inventory.forOutlet(outlet).single.stock, 11);
    expect(finance.recordConsignmentSale(outletId: outlet, batchId: batch.id, quantity: 3), isTrue);
    expect(finance.recordConsignmentSale(outletId: outlet, batchId: batch.id, quantity: 6), isFalse);
    expect(finance.settleConsignment(outletId: outlet, batchId: batch.id, amount: 16000), isTrue);
    expect(finance.addExpense(outletId: outlet, category: 'Listrik', amount: 125000, method: 'Transfer', note: 'Tagihan bulanan'), isTrue);
    await finance.waitForPendingSave();
    batch = finance.consignmentsForOutlet(outlet).single;
    expect(batch.amountDue, 0);
    expect(batch.remainingQuantity, 5);
    expect(finance.totalExpenses(outlet), 125000);
    expect(finance.exportLocalSnapshot()['expenses'], hasLength(1));
  });
}
