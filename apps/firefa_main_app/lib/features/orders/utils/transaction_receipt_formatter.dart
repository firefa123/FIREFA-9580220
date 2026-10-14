import '../models/cart_item_model.dart';
import '../models/payment_model.dart';
import '../models/receipt_model.dart';
import '../models/transaction_model.dart';

/// Formats the locally generated POS receipt for on-screen viewing/copying.
/// Payment status here is local simulation, not external provider settlement.
class TransactionReceiptFormatter {
  const TransactionReceiptFormatter._();

  static String format({
    required ReceiptModel receipt,
    required TransactionModel transaction,
    required PaymentModel payment,
    required List<CartItemModel> items,
  }) {
    if (receipt.transactionId != transaction.id ||
        receipt.paymentId != payment.id ||
        payment.transactionId != transaction.id) {
      throw ArgumentError('Receipt, payment, and transaction must match.');
    }
    if (items.isEmpty ||
        items.any((item) => item.name.trim().isEmpty ||
            item.quantity <= 0 || item.price < 0)) {
      throw ArgumentError('Receipt items must be valid and non-empty.');
    }
    final itemTotal = items.fold<int>(0, (sum, item) => sum + item.subtotal);
    if (itemTotal.toDouble() != receipt.totalAmount ||
        receipt.totalAmount != transaction.totalAmount ||
        receipt.totalAmount != payment.amount) {
      throw ArgumentError('Receipt items and payment total must match.');
    }

    String money(int value) => 'Rp ${value.toString()}';
    final date = receipt.issuedAt.toLocal();
    final timestamp = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final lines = <String>[
      'FIREFA • STRUK TRANSAKSI',
      'Tanggal: $timestamp',
      'Transaksi: ${receipt.transactionId}',
      'Pembayaran: ${receipt.paymentMethod.toUpperCase()}',
      '--------------------------------',
      for (final item in items) ...[
        '${item.name} x${item.quantity}',
        '  ${money(item.subtotal)}',
      ],
      '--------------------------------',
      'TOTAL: ${money(itemTotal)}',
      'ID pembayaran: ${receipt.paymentId}',
      'Status: LUNAS (SIMULASI LOKAL)',
      'Bukan bukti settlement bank.',
    ];
    return lines.join('\\n');
  }
}
