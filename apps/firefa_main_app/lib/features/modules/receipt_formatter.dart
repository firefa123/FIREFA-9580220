import 'order_models.dart';
import 'settings_store.dart';

/// Text receipt for a local order. Does not represent bank settlement.
class FirefaReceiptFormatter {
  const FirefaReceiptFormatter._();

  static String format({
    required FirefaOrder order,
    required String outletName,
    required FirefaOutletSettings settings,
  }) {
    if (settings.outletId != order.outletId) {
      throw ArgumentError('Receipt settings must match order outlet');
    }
    String money(int value) => 'Rp $value';
    final lines = <String>[
      outletName,
      if (settings.address.trim().isNotEmpty) settings.address.trim(),
      if (settings.contact.trim().isNotEmpty) 'Kontak: ${settings.contact.trim()}',
      '------------------------------',
      'Pesanan: ${order.id}',
      'Tanggal: ${order.createdAt.toLocal()}',
      'Tipe: ${order.orderType}',
      if (order.tableId != null) 'Meja: ${order.tableId}',
      'Status: ${order.status.label}',
      'Pembayaran: ${order.paymentStatus.name.toUpperCase()} (demo)',
      '------------------------------',
      for (final item in order.items) ...[
        '${item.productName} x${item.quantity} @ ${money(item.unitPrice)}',
        if (item.details.trim().isNotEmpty) '  ${item.details.trim()}',
        '  ${money(item.total)}',
      ],
      '------------------------------',
      'Subtotal: ${money(order.subtotal)}',
      if (order.discount != 0) 'Diskon: -${money(order.discount)}',
      if (settings.showTaxOnReceipt) 'Pajak: ${money(order.tax)}',
      if (order.service != 0) 'Service: ${money(order.service)}',
      'TOTAL: ${money(order.total)}',
      if (!settings.showTaxOnReceipt)
        'Total sudah termasuk komponen pajak sesuai pesanan.',
      '------------------------------',
      if (settings.receiptFooter.trim().isNotEmpty)
        settings.receiptFooter.trim(),
      'Struk lokal • bukan bukti settlement bank',
    ];
    return lines.join('\n');
  }
}
