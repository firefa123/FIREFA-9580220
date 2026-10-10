import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PosPaymentDialog extends StatefulWidget {
  final int total;
  final String orderType;
  final String? table;
  final int itemCount;

  const PosPaymentDialog({
    super.key,
    required this.total,
    required this.orderType,
    required this.itemCount,
    this.table,
  });

  @override
  State<PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<PosPaymentDialog> {
  static const primary = Color(0xFF008F83);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  String method = 'Cash';
  String splitMethod = 'QRIS';

  final cashController = TextEditingController();
  final splitCashController = TextEditingController();
  final splitOtherController = TextEditingController();

  int get cashReceived => parseAmount(cashController.text);
  int get splitCash => parseAmount(splitCashController.text);
  int get splitOther => parseAmount(splitOtherController.text);

  int get change {
    if (method != 'Cash') return 0;
    return (cashReceived - widget.total).clamp(0, 999999999999);
  }

  int get remaining {
    if (method != 'Split') return 0;
    return (widget.total - splitCash - splitOther).clamp(0, 999999999999);
  }

  bool get canConfirm {
    if (widget.total <= 0) return false;

    switch (method) {
      case 'Cash':
        return cashReceived >= widget.total;
      case 'Split':
        return splitCash > 0 &&
            splitOther > 0 &&
            splitCash + splitOther == widget.total;
      default:
        return true;
    }
  }

  int parseAmount(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  String rupiah(int value) {
    final digits = value.toString();
    return 'Rp ${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  @override
  void dispose() {
    cashController.dispose();
    splitCashController.dispose();
    splitOtherController.dispose();
    super.dispose();
  }

  void confirmPayment() {
    if (!canConfirm) return;

    // Hanya mengembalikan hasil simulasi ke halaman POS.
    // Belum menyimpan transaksi ataupun memproses uang.
    Navigator.of(context).pop(
      PosPaymentResult(
        method: method,
        total: widget.total,
        received: method == 'Cash'
            ? cashReceived
            : method == 'Split'
            ? splitCash + splitOther
            : widget.total,
        change: change,
        splitMethod: method == 'Split' ? splitMethod : null,
        splitCash: method == 'Split' ? splitCash : 0,
        splitOther: method == 'Split' ? splitOther : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 740),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Payment',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.orderType}'
                '${widget.table == null ? '' : ' • Table ${widget.table}'}'
                ' • ${widget.itemCount} items',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text('Total Amount', style: TextStyle(color: muted)),
                    const SizedBox(height: 7),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rupiah(widget.total),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold, color: ink),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  methodChip('Cash', Icons.payments_outlined),
                  methodChip('QRIS', Icons.qr_code_2),
                  methodChip('Transfer', Icons.account_balance_outlined),
                  methodChip('Split', Icons.call_split_outlined),
                ],
              ),
              const SizedBox(height: 24),
              if (method == 'Cash') buildCash(),
              if (method == 'QRIS') buildNonCash('QRIS'),
              if (method == 'Transfer') buildNonCash('Transfer'),
              if (method == 'Split') buildSplit(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: canConfirm ? confirmPayment : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Demo Payment'),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Simulation only • No real money movement',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget methodChip(String value, IconData icon) {
    final selected = method == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? primary : muted),
          const SizedBox(width: 6),
          Text(value),
        ],
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: const Color(0xFFE0F2F1),
      side: BorderSide(color: selected ? primary : border),
      onSelected: (_) {
        setState(() => method = value);
      },
    );
  }

  Widget amountField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget buildCash() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        amountField(controller: cashController, label: 'Cash Received'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amount in <int>{
              widget.total,
              ((widget.total + 9999) ~/ 10000) * 10000,
              ((widget.total + 49999) ~/ 50000) * 50000,
            })
              ActionChip(
                label: Text(rupiah(amount)),
                onPressed: () {
                  cashController.text = amount.toString();
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        summaryRow('Amount Due', rupiah(widget.total)),
        const SizedBox(height: 10),
        summaryRow('Received', rupiah(cashReceived)),
        const SizedBox(height: 10),
        summaryRow('Change', rupiah(change), highlight: true),
        if (cashReceived < widget.total)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Nominal diterima belum mencukupi.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget buildNonCash(String type) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            type == 'QRIS' ? Icons.qr_code_2 : Icons.account_balance_outlined,
            size: 44,
            color: primary,
          ),
          const SizedBox(height: 12),
          Text(
            '$type — Demo',
            style: const TextStyle(fontWeight: FontWeight.bold, color: ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Belum ada QR pembayaran, rekening tujuan, '
            'atau verifikasi transaksi. Konfirmasi di sini '
            'hanya untuk menguji tampilan dan alur POS.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }

  Widget buildSplit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Split Payment',
          style: TextStyle(fontWeight: FontWeight.bold, color: ink),
        ),
        const SizedBox(height: 12),
        amountField(controller: splitCashController, label: 'Cash Amount'),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: splitMethod,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Second Payment Method',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'QRIS', child: Text('QRIS (Demo)')),
            DropdownMenuItem(value: 'Transfer', child: Text('Transfer (Demo)')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => splitMethod = value);
            }
          },
        ),
        const SizedBox(height: 14),
        amountField(
          controller: splitOtherController,
          label: '$splitMethod Amount',
        ),
        const SizedBox(height: 16),
        summaryRow('Allocated', rupiah(splitCash + splitOther)),
        const SizedBox(height: 10),
        summaryRow('Remaining', rupiah(remaining), highlight: true),
        if (splitCash + splitOther > widget.total)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Jumlah pembayaran melebihi total tagihan.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        const Text(
          'Split Payment saat ini mendukung dua bagian: '
          'Cash + QRIS atau Cash + Transfer.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }

  Widget summaryRow(String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: highlight ? 18 : 13,
            color: highlight ? primary : ink,
          ),
        ),
      ],
    );
  }
}

class PosPaymentResult {
  final String method;
  final int total;
  final int received;
  final int change;
  final String? splitMethod;
  final int splitCash;
  final int splitOther;

  const PosPaymentResult({
    required this.method,
    required this.total,
    required this.received,
    required this.change,
    required this.splitMethod,
    required this.splitCash,
    required this.splitOther,
  });
}
