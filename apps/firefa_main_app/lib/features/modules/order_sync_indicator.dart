import 'package:flutter/material.dart';

import 'order_sync_status.dart';

class FirefaOrderSyncIndicator extends StatelessWidget {
  final FirefaOrderSyncStatus status;

  const FirefaOrderSyncIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      FirefaOrderSyncStatus.localOnly =>
        (Icons.cloud_off, 'Local Only'),
      FirefaOrderSyncStatus.queued =>
        (Icons.schedule, 'Queued'),
      FirefaOrderSyncStatus.syncing =>
        (Icons.sync, 'Syncing'),
      FirefaOrderSyncStatus.synced =>
        (Icons.cloud_done, 'Synced'),
      FirefaOrderSyncStatus.conflict =>
        (Icons.warning_amber, 'Conflict'),
      FirefaOrderSyncStatus.failed =>
        (Icons.error_outline, 'Failed'),
    };

    return Chip(
      avatar: Icon(config.$1, size: 18),
      label: Text(config.$2),
    );
  }
}
