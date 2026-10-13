import 'package:flutter/material.dart';

import '../../modules/conflict_store.dart';
import '../../modules/hybrid_sync_conflict_bridge.dart';
import '../../modules/offline_sync_queue.dart';
import '../../modules/sync_adapter.dart';
import '../../modules/sync_coordinator.dart';

/// Shows local outbox state and runs the coordinator through the configured
/// adapter. The default adapter is intentionally disabled until an authenticated
/// backend transport is implemented and configured.
class SyncStatusCard extends StatefulWidget {
  const SyncStatusCard({
    super.key,
    required this.outletId,
    this.adapter = const FirefaDisabledSyncAdapter(),
  });

  final String outletId;
  final FirefaSyncAdapter adapter;

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  bool _isSyncing = false;
  String? _lastMessage;
  FirefaSyncRunSummary? _lastSummary;

  Future<void> _runSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _lastMessage = null;
      _lastSummary = null;
    });

    try {
      final queue = FirefaOfflineSyncQueue.instance;
      await queue.retryFailedForOutlet(widget.outletId);
      final summary = await FirefaSyncCoordinator(
        queue: queue,
        adapter: widget.adapter,
        conflictBridge: FirefaHybridSyncConflictBridge(
          store: FirefaConflictStore.instance,
        ),
      ).syncOutlet(widget.outletId);

      if (!mounted) return;
      setState(() {
        _lastSummary = summary;
        if (summary.attempted == 0) {
          final hasDeferredRetry = queue.entriesForOutlet(widget.outletId).any(
            (entry) =>
                entry.status == FirefaSyncStatus.pending &&
                entry.nextAttemptAt != null &&
                entry.nextAttemptAt!.isAfter(DateTime.now().toUtc()),
          );
          _lastMessage = hasDeferredRetry
              ? 'Ada event menunggu jeda retry. Coba lagi setelah waktunya tiba.'
              : 'Tidak ada event pending yang siap diproses.';
        } else if (summary.conflicts > 0) {
          _lastMessage =
              'Ditemukan ${summary.conflicts} konflik. Periksa Pusat Konflik.';
        } else if (summary.retryableFailures > 0 &&
            summary.acknowledged == 0) {
          _lastMessage =
              'Backend belum mengonfirmasi sinkronisasi. Data tetap tersimpan lokal.';
        } else if (summary.retryableFailures > 0) {
          _lastMessage =
              '${summary.acknowledged} event dikonfirmasi; ${summary.retryableFailures} masih menunggu.';
        } else {
          _lastMessage =
              '${summary.acknowledged} event mendapat konfirmasi valid.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastMessage =
            'Sinkronisasi belum dapat dijalankan. Data lokal tidak dihapus.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = FirefaOfflineSyncQueue.instance;
    final conflictStore = FirefaConflictStore.instance;

    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) => AnimatedBuilder(
        animation: conflictStore,
        builder: (context, _) {
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
          final queuedConflicts = entries
              .where((entry) => entry.status == FirefaSyncStatus.conflict)
              .length;
          final conflicts = conflictStore.conflicts
              .where((conflict) => conflict.outletId == widget.outletId)
              .length;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Sinkronisasi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text('Pending: $pending'),
                  Text('Sedang diproses: $syncing'),
                  Text('Gagal: $failed'),
                  Text('Konflik di antrean: $queuedConflicts'),
                  Text('Konflik perlu ditinjau: $conflicts'),
                  const SizedBox(height: 8),
                  const Text(
                    'Mode: Lokal Offline. Cloud sync hanya aktif setelah '
                    'backend terautentikasi dikonfigurasi.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSyncing ? null : _runSync,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        _isSyncing ? 'Memproses antrean...' : 'Coba sinkronisasi',
                      ),
                    ),
                  ),
                  if (_lastMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _lastMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_lastSummary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Diproses: ${_lastSummary!.attempted} · '
                      'Terkonfirmasi: ${_lastSummary!.acknowledged} · '
                      'Konflik: ${_lastSummary!.conflicts} · '
                      'Menunggu: ${_lastSummary!.retryableFailures}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
