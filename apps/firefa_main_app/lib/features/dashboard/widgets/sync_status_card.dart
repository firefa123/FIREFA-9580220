import 'package:flutter/material.dart';

import '../../modules/offline_sync_queue.dart';
import '../../sync/hybrid_sync_status.dart';
import 'hybrid_status_badge.dart';

class SyncStatusCard extends StatefulWidget {
  const SyncStatusCard({super.key, required this.outletId});

  final String outletId;

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  final queue = FirefaOfflineSyncQueue.instance;
  final hybridStatus = FirefaHybridSyncStatus.instance;

  @override
  void initState() {
    super.initState();
    queue.addListener(_refresh);
    hybridStatus.addListener(_refresh);
  }

  @override
  void dispose() {
    queue.removeListener(_refresh);
    hybridStatus.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _lastSyncLabel() {
    final value = hybridStatus.lastSyncAt;
    if (value == null) return 'Belum pernah';

    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final entries = queue.entriesForOutlet(widget.outletId);
    final pending = entries
        .where((entry) => entry.status == FirefaSyncStatus.pending)
        .length;
    final syncing = entries
        .where((entry) => entry.status == FirefaSyncStatus.syncing)
        .length;
    final failed = entries
        .where((entry) => entry.status == FirefaSyncStatus.failed)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Sync Management',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                HybridStatusBadge(),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Last sync',
              value: _lastSyncLabel(),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Pending transactions',
              value: '$pending',
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Syncing',
              value: '$syncing',
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Failed',
              value: '$failed',
            ),
            if (hybridStatus.message != null &&
                hybridStatus.message!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                hybridStatus.message!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (hybridStatus.isOffline) ...[
              const SizedBox(height: 14),
              const Text(
                'Transaksi tetap disimpan di perangkat dan antrean sync '
                'dipertahankan sampai cloud FIREFA tersedia.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
