import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/auth/role_permissions.dart';

import 'backend_client.dart';
import 'conflict_store.dart';
import 'firefa_http_sync_adapter.dart';
import 'inventory_backend_sync.dart';
import 'hybrid_sync_conflict_bridge.dart';
import 'offline_sync_queue.dart';
import 'sync_coordinator.dart';

/// Foreground recovery worker. It retries durable pending events at startup,
/// after app resume, when the outbox changes, and periodically while the app is
/// open. It never removes pending events when the network is unavailable.
class FirefaSyncWorker with WidgetsBindingObserver {
  FirefaSyncWorker._();

  static final FirefaSyncWorker instance = FirefaSyncWorker._();
  static const Duration _pollInterval = Duration(seconds: 30);

  final FirefaOfflineSyncQueue _queue = FirefaOfflineSyncQueue.instance;
  final FirefaHttpSyncAdapter _adapter = FirefaHttpSyncAdapter();
  Timer? _timer;
  bool _started = false;
  bool _running = false;
  bool _requestedWhileRunning = false;

  Future<void> start() async {
    if (_started || !FirefaBackendConfig.isConfigured) return;
    _started = true;
    await _queue.initialize();
    await FirefaConflictStore.instance.initialize();
    _queue.addListener(_onQueueChanged);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  void _onQueueChanged() {
    if (!_started || !FirefaBackendConfig.isConfigured) return;
    try {
      final now = DateTime.now().toUtc();
      for (final outletId in FirefaBackendConfig.validatedOutletMap.keys) {
        if (_queue.entriesForOutlet(outletId).any((entry) =>
            entry.status == FirefaSyncStatus.pending &&
            (entry.nextAttemptAt == null ||
                !entry.nextAttemptAt!.toUtc().isAfter(now)))) {
          unawaited(syncNow());
          return;
        }
      }
    } catch (error) {
      debugPrint('FIREFA sync mapping is not ready: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (!_started || !FirefaBackendConfig.isConfigured) return;
    if (_running) {
      _requestedWhileRunning = true;
      return;
    }
    _running = true;
    try {
      final backend = FirefaBackendClient.instance;
      final session = await backend.restoreSession();
      if (session == null) return;
      final mapping = FirefaBackendConfig.validatedOutletMap;
      final authorized = session.outletIds.map((id) => id.toLowerCase()).toSet();
      final localOutlets = mapping.entries
          .where((entry) => authorized.contains(entry.value.toLowerCase()))
          .map((entry) => entry.key)
          .toSet();
      if (localOutlets.isEmpty) return;

      final coordinator = FirefaSyncCoordinator(
        queue: _queue,
        adapter: _adapter,
        conflictBridge: FirefaHybridSyncConflictBridge(
          store: FirefaConflictStore.instance,
        ),
      );
      for (final outletId in localOutlets) {
        if (!_started) break;
        try {
          final orderResult = await coordinator.syncOutlet(outletId);
          if (orderResult.retryableFailures > 0 || orderResult.conflicts > 0) {
            debugPrint('FIREFA order sync $outletId: acknowledged=${orderResult.acknowledged}, retry=${orderResult.retryableFailures}, conflicts=${orderResult.conflicts}');
          }
          if (session.role == FirefaRole.owner) {
            final inventoryResult = await FirefaInventoryBackendSync.instance.syncOutlet(outletId);
            if (inventoryResult.failed > 0) {
              debugPrint('FIREFA inventory sync $outletId deferred: ${inventoryResult.errors.join('; ')}');
            } else if (inventoryResult.attempted > 0) {
              try {
                final differences = await FirefaInventoryBackendSync.instance.reconcileOutlet(outletId);
                if (differences.isNotEmpty) {
                  debugPrint('FIREFA inventory reconciliation $outletId found ${differences.length} difference(s); local stock was not overwritten.');
                }
              } catch (error) {
                debugPrint('FIREFA inventory reconciliation deferred safely: $error');
              }
            }
          }
        } catch (error) {
          debugPrint('FIREFA sync outlet failed safely: $error');
        }
      }
    } catch (error) {
      // Offline, expired session, invalid mapping or unavailable backend must
      // not interrupt POS. Pending events stay in the durable outbox.
      debugPrint('FIREFA sync deferred: $error');
    } finally {
      _running = false;
      if (_requestedWhileRunning) {
        _requestedWhileRunning = false;
        unawaited(syncNow());
      }
    }
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _queue.removeListener(_onQueueChanged);
  }
}
