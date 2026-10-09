import 'package:flutter/material.dart';

import '../../modules/offline_sync_queue.dart';

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key, required this.outletId});

  final String outletId;

  @override
  Widget build(BuildContext context) {
    final queue = FirefaOfflineSyncQueue.instance;
    final entries = queue.entriesForOutlet(outletId);
    final pending = entries
        .where((entry) => entry.status == FirefaSyncStatus.pending)
        .length;
    final failed = entries
        .where((entry) => entry.status == FirefaSyncStatus.failed)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text('Pending: $pending'),
            Text('Failed: $failed'),
            const SizedBox(height: 8),
            const Text(
              'Mode: Local Offline\nCloud sync menunggu backend.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
