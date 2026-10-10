import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/purchase_order_store.dart';

void main() {
  FirefaPurchaseOrder order({
    String status = 'ordered',
    String? contactedAt,
    String? followUpDate = '2026-10-09',
  }) => FirefaPurchaseOrder(
        id: 'po-1',
        outletId: 'outlet-1',
        supplierId: 'supplier-1',
        supplierName: 'Supplier A',
        itemId: 'item-1',
        itemName: 'Beras',
        unit: 'kg',
        quantity: 10,
        unitCost: 12000,
        note: '',
        status: status,
        createdAt: '2026-10-01T09:00:00',
        receivedAt: null,
        followUpNote: 'Telepon supplier',
        followUpDate: followUpDate,
        followUpContactedAt: contactedAt,
      );

  test('legacy PO JSON loads without contact timestamp', () {
    final legacy = order().toJson()..remove('followUpContactedAt');
    final restored = FirefaPurchaseOrder.fromJson(legacy);
    expect(restored.followUpContactedAt, isNull);
    expect(restored.followUpNote, 'Telepon supplier');
    expect(restored.remainingQuantity, 10);
  });

  test('contact timestamp survives JSON round trip', () {
    final original = order(contactedAt: '2026-10-09T11:30:00');
    final restored = FirefaPurchaseOrder.fromJson(original.toJson());
    expect(restored.followUpContactedAt, original.followUpContactedAt);
    expect(restored.followUpDate, '2026-10-09');
  });

  test('editing follow-up resets contact confirmation', () {
    final original = order(contactedAt: '2026-10-09T11:30:00');
    final changed = original.withFollowUp('Supplier menjanjikan kirim', '2026-10-10');
    expect(changed.followUpContactedAt, isNull);
    expect(changed.followUpNote, 'Supplier menjanjikan kirim');
  });

  test('contact update does not change stock or PO state', () {
    final original = order(status: 'partial');
    final updated = original.withContactedAt('2026-10-09T12:00:00');
    expect(updated.status, 'partial');
    expect(updated.receivedQuantity, 0);
    expect(updated.remainingQuantity, 10);
    expect(updated.totalCost, 120000);
    expect(updated.outletId, original.outletId);
  });

  test('receipt retains contact history and increments received quantity', () {
    final original = order(contactedAt: '2026-10-09T11:30:00');
    final received = original.withReceipt(const FirefaPurchaseReceipt(
      id: 'po-1-receipt-1',
      quantity: 3,
      receivedAt: '2026-10-09T12:00:00',
    ));
    expect(received.status, 'partial');
    expect(received.receivedQuantity, 3);
    expect(received.remainingQuantity, 7);
    expect(received.followUpContactedAt, original.followUpContactedAt);
    expect(received.receipts, hasLength(1));
  });

  test('cancel retains follow-up audit details', () {
    final original = order(contactedAt: '2026-10-09T11:30:00');
    final cancelled = original.withStatus('cancelled', '2026-10-09T13:00:00');
    expect(cancelled.status, 'cancelled');
    expect(cancelled.followUpContactedAt, original.followUpContactedAt);
    expect(cancelled.followUpNote, original.followUpNote);
  });
}
