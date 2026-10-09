import 'package:flutter/material.dart';

import '../../core/outlet/active_outlet_store.dart';
import '../widgets/sync_status_card.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final outletId = FirefaActiveOutletStore.instance.selectedOutletId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Owner Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SyncStatusCard(outletId: outletId),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _OwnerCard(title: 'Revenue', icon: Icons.payments_outlined),
            _OwnerCard(title: 'Orders', icon: Icons.receipt_long_outlined),
            _OwnerCard(title: 'Outlet Performance', icon: Icons.store_outlined),
            _OwnerCard(title: 'Reports', icon: Icons.analytics_outlined),
          ],
        ),
      ],
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final String title;
  final IconData icon;
  const _OwnerCard({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          width: 180,
          height: 100,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Icon(icon), const Spacer(), Text(title)],
            ),
          ),
        ),
      );
}
