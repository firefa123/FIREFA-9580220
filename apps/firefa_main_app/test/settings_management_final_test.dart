import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/settings_store.dart';

void main() {
  test('settings JSON roundtrip preserves preferences', () {
    const value = FirefaOutletSettings(
      outletId: 'outlet-001',
      receiptFooter: 'Sampai jumpa',
      contact: '0812345678',
      address: 'Jalan Contoh 1',
      showTaxOnReceipt: false,
    );
    final restored = FirefaOutletSettings.fromJson(value.toJson());
    expect(restored.outletId, value.outletId);
    expect(restored.receiptFooter, value.receiptFooter);
    expect(restored.contact, value.contact);
    expect(restored.address, value.address);
    expect(restored.showTaxOnReceipt, false);
  });

  test('default settings are non-destructive', () {
    const value = FirefaOutletSettings(outletId: 'outlet-002');
    expect(value.showTaxOnReceipt, true);
    expect(value.contact, '');
    expect(value.address, '');
    expect(value.receiptFooter, isNotEmpty);
  });

  test('copyWith retains outlet identity and unrelated fields', () {
    const original = FirefaOutletSettings(
      outletId: 'outlet-001', contact: '123', address: 'A',
    );
    final edited = original.copyWith(contact: '456');
    expect(edited.outletId, original.outletId);
    expect(edited.address, 'A');
    expect(edited.contact, '456');
    expect(original.contact, '123');
  });

  test('legacy settings JSON uses safe defaults', () {
    final restored = FirefaOutletSettings.fromJson(
      {'outletId': 'outlet-001'},
    );
    expect(restored.showTaxOnReceipt, true);
    expect(restored.receiptFooter, isNotEmpty);
  });
}
