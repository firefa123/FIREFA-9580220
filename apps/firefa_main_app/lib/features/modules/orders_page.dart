import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'order_models.dart';
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

  String filter = 'All';

  String get outletId => outletStore.selectedOutletId;
  String get outletName => outletStore.selectedOutletName;

  bool get canManage =>
      FirefaAccess.can(outletStore.role, FirefaPermission.ordersManage);

  List<FirefaOrder> get orders => orderStore.ordersForOutlet(outletId);

  List<FirefaOrder> get visibleOrders {
    if (filter == 'All') return orders;

    if (filter == 'Unpaid') {
      return orders.where((order) {
        return order.paymentStatus == FirefaPaymentStatus.unpaid &&
            order.status != FirefaOrderStatus.cancelled;
      }).toList();
    }

    return orders.where((order) {
      return order.status.label == filter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    outletStore.addListener(_refresh);
    orderStore.addListener(_refresh);
  }

  @override
  void dispose() {
    outletStore.removeListener(_refresh);
    orderStore.removeListener(_refresh);
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
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
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
                'Unpaid',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(value),
                    selected: filter == value,
                    showCheckmark: false,
                    selectedColor: const Color(0xFFE0F2F1),
                    onSelected: (_) {
                      setState(() => filter = value);
                    },
                  ),
                ),
            ],
          ),
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
            child: const Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 44, color: muted),
                SizedBox(height: 12),
                Text('Belum ada pesanan'),
                SizedBox(height: 6),
                Text(
                  'Buat pesanan melalui POS di outlet ini.',
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
