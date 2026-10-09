import 'package:flutter/material.dart';

import '../../core/outlet/active_outlet_store.dart';
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

  @override
  Widget build(BuildContext context) {
    final orders = orderStore.ordersForOutlet(outletStore.selectedOutletId)
        .where((order) => order.status != FirefaOrderStatus.completed &&
            order.status != FirefaOrderStatus.cancelled)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kitchen / Bar Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text('Kitchen Queue (${orders.length})'),
        const SizedBox(height: 12),
        for (final order in orders)
          Card(
            child: ListTile(
              title: Text(order.id),
              subtitle: Text(order.items.map((item) => '${item.productName} x${item.quantity}').join(', ')),
              trailing: FilledButton(
                onPressed: () => orderStore.advance(order.outletId, order.id),
                child: Text(order.status.label),
              ),
            ),
          ),
      ],
    );
  }
}
