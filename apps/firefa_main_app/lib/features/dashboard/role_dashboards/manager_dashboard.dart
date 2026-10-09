import 'package:flutter/material.dart';

import '../../core/outlet/active_outlet_store.dart';
import '../widgets/sync_status_card.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final outletId = FirefaActiveOutletStore.instance.selectedOutletId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Manager Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SyncStatusCard(outletId: outletId),
        const SizedBox(height: 16),
        const Text('Operational overview'),
        const Text('• Active orders\n• Outlet activity\n• Inventory monitoring\n• Staff operations'),
      ],
    );
  }
}
