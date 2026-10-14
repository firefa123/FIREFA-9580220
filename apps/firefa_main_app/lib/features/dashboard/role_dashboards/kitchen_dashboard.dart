import 'package:flutter/material.dart';

import '../../../core/outlet/active_outlet_store.dart';
import '../../modules/order_models.dart';
import '../../modules/order_store.dart';

class KitchenDashboard extends StatefulWidget {
  const KitchenDashboard({super.key});

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> {
  final orderStore = FirefaOrderStore.instance;
  final outletStore = FirefaActiveOutletStore.instance;
  final Set<String> _updatingOrders = <String>{};

  @override
  void initState() {
    super.initState();
    orderStore.addListener(_refresh);
    outletStore.addListener(_refresh);
  }

  @override
  void dispose() {
    orderStore.removeListener(_refresh);
    outletStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _nextAction(FirefaOrder order) {
    switch (order.status) {
      case FirefaOrderStatus.draft:
        return 'Konfirmasi';
      case FirefaOrderStatus.confirmed:
        return 'Mulai Siapkan';
      case FirefaOrderStatus.preparing:
        return 'Tandai Siap';
      case FirefaOrderStatus.ready:
        return 'Tandai Disajikan';
      case FirefaOrderStatus.served:
        return order.paymentStatus == FirefaPaymentStatus.paid
            ? 'Selesaikan Order'
            : 'Menunggu Pembayaran';
      case FirefaOrderStatus.completed:
      case FirefaOrderStatus.cancelled:
        return 'Selesai';
    }
  }

  Future<void> _advance(FirefaOrder order) async {
    if (_updatingOrders.contains(order.id) ||
        !outletStore.canAccessOutlet(order.outletId) ||
        order.outletId != outletStore.selectedOutletId) {
      return;
    }

    if (order.status == FirefaOrderStatus.served &&
        order.paymentStatus != FirefaPaymentStatus.paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order harus berstatus Paid sebelum diselesaikan.'),
        ),
      );
      return;
    }

    setState(() => _updatingOrders.add(order.id));
    try {
      final changed = await orderStore.advanceAndPersist(
        outletStore.selectedOutletId,
        order.id,
      );
      if (!mounted) return;
      if (!changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status order tidak dapat dilanjutkan.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status order gagal disimpan: $error')),
      );
    } finally {
      if (mounted) setState(() => _updatingOrders.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outletId = outletStore.selectedOutletId;
    final orders = orderStore.ordersForOutlet(outletId)
        .where((order) =>
            order.status != FirefaOrderStatus.completed &&
            order.status != FirefaOrderStatus.cancelled)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final preparingCount = orders
        .where((order) => order.status == FirefaOrderStatus.preparing)
        .length;
    final readyCount = orders
        .where((order) => order.status == FirefaOrderStatus.ready)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kitchen / Bar Dashboard',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          outletStore.selectedOutletName,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _QueueSummary(label: 'Antrean Aktif', count: orders.length),
            _QueueSummary(label: 'Sedang Disiapkan', count: preparingCount),
            _QueueSummary(label: 'Siap Disajikan', count: readyCount),
          ],
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Belum ada pesanan aktif di outlet ini.'),
              ),
            ),
          )
        else
          for (final order in orders)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.id,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Chip(label: Text(order.status.label)),
                      ],
                    ),
                    Text(
                      [
                        order.orderType,
                        if (order.tableId != null) 'Meja ${order.tableId}',
                        order.paymentStatus == FirefaPaymentStatus.paid
                            ? 'Paid'
                            : 'Unpaid',
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${item.quantity}× ${item.productName}'
                          '${item.details.isEmpty ? '' : ' — ${item.details}'}',
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _updatingOrders.contains(order.id) ||
                                (order.status == FirefaOrderStatus.served &&
                                    order.paymentStatus !=
                                        FirefaPaymentStatus.paid)
                            ? () {
                                if (order.status == FirefaOrderStatus.served &&
                                    order.paymentStatus !=
                                        FirefaPaymentStatus.paid) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Order harus berstatus Paid sebelum diselesaikan.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            : () => _advance(order),
                        child: _updatingOrders.contains(order.id)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_nextAction(order)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _QueueSummary extends StatelessWidget {
  final String label;
  final int count;

  const _QueueSummary({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(child: Text('$count')),
      label: Text(label),
    );
  }
}
