import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'order_models.dart';
import 'offline_sync_queue.dart';
import 'order_store.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const primary = Color(0xFF008F83);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  final outletStore = FirefaActiveOutletStore.instance;
  final orderStore = FirefaOrderStore.instance;
  final syncQueue = FirefaOfflineSyncQueue.instance;
  bool showSyncEvents = false;

  String filter = 'All';
  String searchQuery = '';
  String paymentFilter = 'all';
  DateTimeRange? dateRange;
  final Set<String> expandedOrders = <String>{};

  String get outletId => outletStore.selectedOutletId;
  String get outletName => outletStore.selectedOutletName;

  bool get canManage =>
      FirefaAccess.can(outletStore.role, FirefaPermission.ordersManage);

  List<FirefaOrder> get orders => orderStore.ordersForOutlet(outletId);

  List<FirefaOrder> get visibleOrders {
    final query = searchQuery.trim().toLowerCase();
    return orders.where((order) {
      if (filter == 'Unpaid' &&
          (order.paymentStatus != FirefaPaymentStatus.unpaid ||
              order.status == FirefaOrderStatus.cancelled)) {
        return false;
      }
      if (filter != 'All' && filter != 'Unpaid' &&
          order.status.label != filter) {
        return false;
      }
      if (paymentFilter == 'paid' &&
          order.paymentStatus != FirefaPaymentStatus.paid) {
        return false;
      }
      if (paymentFilter == 'unpaid' &&
          order.paymentStatus != FirefaPaymentStatus.unpaid) {
        return false;
      }
      if (dateRange != null) {
        final day = DateUtils.dateOnly(order.createdAt);
        if (day.isBefore(dateRange!.start) || day.isAfter(dateRange!.end)) {
          return false;
        }
      }
      if (query.isNotEmpty &&
          !order.id.toLowerCase().contains(query) &&
          !order.orderType.toLowerCase().contains(query) &&
          !(order.tableId?.toLowerCase().contains(query) ?? false) &&
          !order.items.any((item) =>
              item.productName.toLowerCase().contains(query))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    final safe = escaped.isNotEmpty && '=+-@'.contains(escaped[0])
        ? "'$escaped" : escaped;
    return '"$safe"';
  }

  Future<void> _copyOrdersCsv() async {
    final selectedOutlet = outletId;
    if (!canManage || !outletStore.canAccessOutlet(selectedOutlet)) {
      return;
    }
    final rows = visibleOrders;
    if (rows.any((order) => order.outletId != selectedOutlet)) {
      return;
    }
    final csv = <String>[
      'Order ID,Outlet ID,Tanggal,Tipe,Meja,Status,Pembayaran,Item Qty,Subtotal,Diskon,Pajak,Service,Total,Produk',
      for (final order in rows)
        [
          order.id, order.outletId, order.createdAt.toIso8601String(),
          order.orderType, order.tableId ?? '', order.status.label,
          order.paymentStatus.name, order.itemCount.toString(),
          order.subtotal.toString(), order.discount.toString(),
          order.tax.toString(), order.service.toString(),
          order.total.toString(),
          order.items.map((item) => '${item.productName} x${item.quantity}').join('; '),
        ].map(_csvCell).join(','),
    ].join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted || outletId != selectedOutlet ||
        !canManage || !outletStore.canAccessOutlet(selectedOutlet)) {
      return;
    }
    message('CSV ${rows.length} pesanan disalin ke clipboard.');
  }

  Future<void> _chooseDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dateRange,
    );
    if (!mounted || picked == null) return;
    setState(() => dateRange = picked);
  }

  @override
  void initState() {
    super.initState();
    outletStore.addListener(_refresh);
    orderStore.addListener(_refresh);
    syncQueue.addListener(_refresh);
  }

  @override
  void dispose() {
    outletStore.removeListener(_refresh);
    orderStore.removeListener(_refresh);
    syncQueue.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String rupiah(int value) =>
      'Rp ${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool canActOn(FirefaOrder order) {
    return canManage &&
        outletStore.canAccessOutlet(order.outletId) &&
        order.outletId == outletId;
  }

  void advance(FirefaOrder order) {
    if (!canActOn(order)) {
      message('Anda tidak memiliki izin untuk pesanan ini.');
      return;
    }

    final success = orderStore.advance(outletId, order.id);

    message(
      success
          ? '${order.id} sekarang ${order.status.label}'
          : 'Status tidak dapat dilanjutkan.',
    );
  }

  void cancel(FirefaOrder order) {
    if (!canActOn(order)) {
      message('Anda tidak memiliki izin untuk pesanan ini.');
      return;
    }

    final success = orderStore.cancel(outletId, order.id);

    message(
      success ? '${order.id} dibatalkan.' : 'Pesanan tidak dapat dibatalkan.',
    );
  }

  void markPaid(FirefaOrder order) {
    if (!canActOn(order)) {
      message('Anda tidak memiliki izin untuk pesanan ini.');
      return;
    }

    final success = orderStore.markPaid(outletId, order.id);

    message(
      success
          ? '${order.id} ditandai Paid (demo).'
          : 'Status pembayaran tidak dapat diubah.',
    );
  }

  Color statusColor(FirefaOrderStatus status) {
    switch (status) {
      case FirefaOrderStatus.draft:
        return Colors.blueGrey;
      case FirefaOrderStatus.confirmed:
        return Colors.blue;
      case FirefaOrderStatus.preparing:
        return Colors.deepOrange;
      case FirefaOrderStatus.ready:
        return Colors.teal;
      case FirefaOrderStatus.served:
        return Colors.indigo;
      case FirefaOrderStatus.completed:
        return Colors.green;
      case FirefaOrderStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOrders = orders;

    final active = currentOrders.where((order) {
      return order.status != FirefaOrderStatus.completed &&
          order.status != FirefaOrderStatus.cancelled;
    }).length;

    final unpaid = currentOrders.where((order) {
      return order.paymentStatus == FirefaPaymentStatus.unpaid &&
          order.status != FirefaOrderStatus.cancelled;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 18, color: primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Orders — $outletName',
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              summaryCard(
                'Total Orders',
                currentOrders.length,
                Icons.receipt_long,
              ),
              summaryCard('Active Orders', active, Icons.pending_actions),
              summaryCard('Unpaid', unpaid, Icons.payments_outlined),
            ];

            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        syncMonitoringPanel(),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text('Daftar Pesanan',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ink)),
            ),
            Text('${visibleOrders.length} pesanan',
                style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Filter status pesanan dan pembayaran • Outlet aktif',
            style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 12),
        const Text('Status order',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in const [
              'All',
              'Draft',
              'Confirmed',
              'Preparing',
              'Ready',
              'Served',
              'Completed',
              'Cancelled',
            ])
              ChoiceChip(
                label: Text(value),
                selected: filter == value,
                showCheckmark: false,
                selectedColor: const Color(0xFFE0F2F1),
                onSelected: (_) {
                  setState(() => filter = value);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Pembayaran:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
            ChoiceChip(
              label: const Text('Unpaid'),
              selected: filter == 'Unpaid',
              showCheckmark: false,
              selectedColor: const Color(0xFFE0F2F1),
              onSelected: (_) => setState(() => filter = filter == 'Unpaid' ? 'All' : 'Unpaid'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 260, child: TextField(
              decoration: const InputDecoration(
                labelText: 'Cari ID, produk, tipe atau meja',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            )),
            DropdownButton<String>(
              value: paymentFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Semua pembayaran')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => paymentFilter = value);
              },
            ),
            OutlinedButton.icon(
              onPressed: _chooseDateRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(dateRange == null ? 'Rentang tanggal'
                  : '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} - '
                    '${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}'),
            ),
            if (dateRange != null)
              TextButton(onPressed: () => setState(() => dateRange = null),
                child: const Text('Hapus tanggal')),
            OutlinedButton.icon(
              onPressed: canManage && outletStore.canAccessOutlet(outletId)
                  ? _copyOrdersCsv : null,
              icon: const Icon(Icons.copy_all_outlined),
              label: Text('Salin CSV (${visibleOrders.length})'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (visibleOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(42),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 44, color: muted),
                const SizedBox(height: 12),
                Text(filter == 'All' ? 'Belum ada pesanan' : 'Tidak ada hasil untuk filter $filter'),
                const SizedBox(height: 6),
                const Text(
                  'Coba filter lain atau buat pesanan melalui POS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        for (final order in visibleOrders) orderCard(order),
      ],
    );
  }

  Widget syncMonitoringPanel() {
    final entries = syncQueue.entriesForOutlet(outletId).reversed.toList();
    int count(FirefaSyncStatus status) =>
        entries.where((entry) => entry.status == status).length;

    final counters = [
      ('Pending', count(FirefaSyncStatus.pending), Colors.orange),
      ('Syncing', count(FirefaSyncStatus.syncing), Colors.blue),
      ('Synced', count(FirefaSyncStatus.synced), Colors.green),
      ('Failed', count(FirefaSyncStatus.failed), Colors.red),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, color: muted),
              Text(
                'Sync Monitoring',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ink),
              ),
              Text(
                'Local Only — Cloud belum terhubung',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Antrean perubahan pesanan untuk $outletName. '
            'Belum ada pengiriman ke server.',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final counter in counters)
                chip('${counter.$1}: ${counter.$2}', counter.$3),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => setState(() => showSyncEvents = !showSyncEvents),
            icon: Icon(showSyncEvents ? Icons.expand_less : Icons.expand_more),
            label: Text(showSyncEvents ? 'Tutup riwayat event' : 'Lihat riwayat event (${entries.length})'),
          ),
          if (showSyncEvents) ...[
            const Divider(),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Belum ada event sinkronisasi untuk outlet ini.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            for (final entry in entries.take(50))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          entry.orderId,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: ink),
                        ),
                        chip(entry.status.name.toUpperCase(), switch (entry.status) {
                          FirefaSyncStatus.pending => Colors.orange,
                          FirefaSyncStatus.syncing => Colors.blue,
                          FirefaSyncStatus.synced => Colors.green,
                          FirefaSyncStatus.failed => Colors.red,
                        }),
                        Text(entry.eventType, style: const TextStyle(color: muted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'Event: ${entry.eventId}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    Text(
                      'Waktu: ${entry.createdAt.toLocal()}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            if (entries.length > 50)
              Text(
                'Menampilkan 50 event terbaru dari ${entries.length} event.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }

  Widget summaryCard(String title, int count, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: muted, fontSize: 12)),
              Text(
                '$count',
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 23,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget amountRow(String label, int value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Text(
            rupiah(value),
            style: TextStyle(
              color: bold ? primary : ink,
              fontSize: bold ? 17 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget orderCard(FirefaOrder order) {
    final expanded = expandedOrders.contains(order.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                order.id,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              chip(order.status.label, statusColor(order.status)),
              chip(
                order.paymentStatus == FirefaPaymentStatus.paid
                    ? 'Paid'
                    : 'Unpaid',
                order.paymentStatus == FirefaPaymentStatus.paid
                    ? Colors.green
                    : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${order.orderType}'
            '${order.tableId == null ? '' : ' • Table ${order.tableId}'}'
            ' • ${order.itemCount} items',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  rupiah(order.total),
                  style: const TextStyle(
                    color: primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                key: ValueKey('details-${order.id}'),
                onPressed: () => setState(() {
                  if (expanded) {
                    expandedOrders.remove(order.id);
                  } else {
                    expandedOrders.add(order.id);
                  }
                }),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(expanded ? 'Tutup Detail' : 'Lihat Detail'),
              ),
            ],
          ),
          if (expanded) ...[
          const SizedBox(height: 16),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}× ${item.productName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        if (item.details.isNotEmpty)
                          Text(
                            item.details,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    rupiah(item.total),
                    style: const TextStyle(fontSize: 12, color: ink),
                  ),
                ],
              ),
            ),
          const Divider(height: 26),
          amountRow('Subtotal', order.subtotal),
          if (order.discount > 0) amountRow('Discount', -order.discount),
          if (order.tax > 0) amountRow('Tax', order.tax),
          if (order.service > 0) amountRow('Service', order.service),
          const Divider(height: 20),
          amountRow('Grand Total', order.total, bold: true),
          ],
          if (canManage) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (order.status.next != null)
                  FilledButton.icon(
                    onPressed:
                        !canActOn(order) ||
                            (order.status.next == FirefaOrderStatus.completed &&
                                !order.canComplete)
                        ? null
                        : () => advance(order),
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text('Move to ${order.status.next!.label}'),
                  ),
                if (order.paymentStatus == FirefaPaymentStatus.unpaid &&
                    order.status != FirefaOrderStatus.draft &&
                    order.status != FirefaOrderStatus.cancelled)
                  OutlinedButton.icon(
                    onPressed: canActOn(order) ? () => markPaid(order) : null,
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Mark Paid (Demo)'),
                  ),
                if (order.status.canCancel &&
                    order.paymentStatus == FirefaPaymentStatus.unpaid)
                  TextButton.icon(
                    onPressed: canActOn(order) ? () => cancel(order) : null,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
