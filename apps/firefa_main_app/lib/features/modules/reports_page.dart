import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'order_models.dart';
import 'order_store.dart';

/// Local-only, read-only reports derived from actual POS orders.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const primary = Color(0xFF008F83);
  static const muted = Color(0xFF64748B);
  final outlet = FirefaActiveOutletStore.instance;
  final orders = FirefaOrderStore.instance;
  late final Future<void> ready;
  DateTimeRange? dateRange;
  String statusFilter = 'all';

  bool get allowed => FirefaAccess.can(outlet.role, FirefaPermission.reportsView) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

  @override
  void initState() {
    super.initState();
    ready = orders.initialize();
    outlet.addListener(_refresh);
    orders.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    outlet.removeListener(_refresh);
    orders.removeListener(_refresh);
    super.dispose();
  }

  List<FirefaOrder> _filtered(String outletId) {
    if (!allowed || outlet.selectedOutletId != outletId) return [];
    final result = orders.ordersForOutlet(outletId).where((order) {
      if (statusFilter == 'paid' &&
          order.paymentStatus != FirefaPaymentStatus.paid) {
        return false;
      }
      if (statusFilter == 'unpaid' &&
          order.paymentStatus != FirefaPaymentStatus.unpaid) {
        return false;
      }
      if (statusFilter == 'completed' &&
          order.status != FirefaOrderStatus.completed) {
        return false;
      }
      if (dateRange != null) {
        final day = DateUtils.dateOnly(order.createdAt);
        if (day.isBefore(dateRange!.start) || day.isAfter(dateRange!.end)) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  String _money(int value) {
    final digits = value.abs().toString();
    final grouped = digits.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
    return 'Rp ${value < 0 ? '-' : ''}$grouped';
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    final safe = escaped.isNotEmpty && '=+-@'.contains(escaped[0])
        ? "'$escaped" : escaped;
    return '"$safe"';
  }

  Future<void> _copyCsv(String outletId, List<FirefaOrder> visible) async {
    if (!allowed || outlet.selectedOutletId != outletId ||
        visible.any((order) => order.outletId != outletId)) {
      return;
    }
    final csv = <String>[
      'Order ID,Outlet ID,Tanggal,Tipe,Meja,Status,Pembayaran,Item Qty,Subtotal,Diskon,Pajak,Service,Total',
      for (final order in visible)
        [
          order.id, order.outletId, order.createdAt.toIso8601String(),
          order.orderType, order.tableId ?? '', order.status.label,
          order.paymentStatus.name, order.itemCount.toString(),
          order.subtotal.toString(), order.discount.toString(),
          order.tax.toString(), order.service.toString(),
          order.total.toString(),
        ].map(_csvCell).join(','),
    ].join('\r\n');
    if (!mounted || !allowed || outlet.selectedOutletId != outletId) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted || !allowed || outlet.selectedOutletId != outletId) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('CSV ${visible.length} pesanan disalin ke clipboard.'),
    ));
  }

  Future<void> _selectDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dateRange,
    );
    if (mounted && picked != null) setState(() => dateRange = picked);
  }

  Widget _metric(String title, String value) => Container(
    width: 190,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Gagal membaca laporan lokal. Data tidak diubah.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!allowed) {
          return const Text('Anda tidak memiliki akses ke Reports.');
        }
        final outletId = outlet.selectedOutletId;
        final visible = _filtered(outletId);
        final paid = visible.where((order) =>
            order.paymentStatus == FirefaPaymentStatus.paid &&
            order.status != FirefaOrderStatus.cancelled).toList();
        final completed = visible.where((order) =>
            order.status == FirefaOrderStatus.completed).length;
        final unpaid = visible.where((order) =>
            order.paymentStatus == FirefaPaymentStatus.unpaid &&
            order.status != FirefaOrderStatus.cancelled).length;
        final cancelled = visible.where((order) =>
            order.status == FirefaOrderStatus.cancelled).length;
        final paidTotal = paid.fold<int>(0, (sum, order) => sum + order.total);
        final byProduct = <String, int>{};
        for (final order in paid) {
          for (final item in order.items) {
            byProduct.update(item.productName, (value) => value + item.quantity,
                ifAbsent: () => item.quantity);
          }
        }
        final topProducts = byProduct.entries.toList()
          ..sort((a, b) {
            final qty = b.value.compareTo(a.value);
            return qty != 0 ? qty : a.key.compareTo(b.key);
          });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reports & Analytics',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${outlet.selectedOutletName} • Laporan dari pesanan lokal',
                style: const TextStyle(color: muted)),
            const SizedBox(height: 6),
            const Text('Pembayaran masih simulasi. Nilai Paid bukan settlement bank, '
                'dan tidak termasuk biaya operasional atau laba.',
                style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua pesanan')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => statusFilter = value);
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _selectDates,
                  icon: const Icon(Icons.date_range),
                  label: Text(dateRange == null ? 'Pilih tanggal'
                      : '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} - '
                        '${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final today = DateUtils.dateOnly(DateTime.now());
                    setState(() => dateRange = DateTimeRange(start: today, end: today));
                  },
                  icon: const Icon(Icons.today),
                  label: const Text('Hari ini'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    dateRange = null;
                    statusFilter = 'all';
                  }),
                  child: const Text('Reset filter'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyCsv(outletId, visible),
                  icon: const Icon(Icons.copy_all),
                  label: Text('Salin CSV (${visible.length})'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _metric('Total pesanan', '${visible.length}'),
              _metric('Completed', '$completed'),
              _metric('Paid', '${paid.length}'),
              _metric('Unpaid aktif', '$unpaid'),
              _metric('Cancelled', '$cancelled'),
              _metric('Nilai pembayaran Paid', _money(paidTotal)),
            ]),
            const SizedBox(height: 24),
            const Text('Produk terjual (pesanan Paid)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (topProducts.isEmpty)
              const Text('Belum ada produk dari pesanan Paid pada filter ini.',
                  style: TextStyle(color: muted)),
            for (final entry in topProducts.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(child: Text(entry.key,
                      overflow: TextOverflow.ellipsis)),
                  Text('${entry.value} item',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 22),
            const Text('Pesanan dalam laporan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              const Text('Tidak ada pesanan untuk filter ini.',
                  style: TextStyle(color: muted)),
            for (final order in visible.take(30))
              Card(child: ListTile(
                title: Text(order.id),
                subtitle: Text('${order.createdAt.day}/${order.createdAt.month}/'
                    '${order.createdAt.year} • ${order.orderType} • '
                    '${order.status.label} • ${order.paymentStatus.name}'),
                trailing: Text(_money(order.total)),
              )),
            if (visible.length > 30)
              const Text('Menampilkan 30 pesanan terbaru. CSV mencakup seluruh hasil filter.',
                  style: TextStyle(color: muted, fontSize: 12)),
          ],
        );
      },
    );
  }
}
