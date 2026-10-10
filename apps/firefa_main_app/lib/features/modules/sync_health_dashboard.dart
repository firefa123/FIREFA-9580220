import 'package:flutter/material.dart';

import 'conflict_store.dart';

/// Owner monitoring widget for hybrid sync health.
/// Metrics are intentionally read-only until connected with real sync service.
class FirefaSyncHealthDashboard extends StatelessWidget {
  final int pendingOutbox;
  final int successfulSync;
  final int failedSync;

  const FirefaSyncHealthDashboard({
    super.key,
    this.pendingOutbox = 0,
    this.successfulSync = 0,
    this.failedSync = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FirefaConflictStore.instance,
      builder: (context, _) {
        final conflicts = FirefaConflictStore.instance.conflicts.length;
        return Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.sync),
                title: Text('Sync Health'),
              ),
              ListTile(
                title: const Text('Pending Outbox'),
                trailing: Text('$pendingOutbox'),
              ),
              ListTile(
                title: const Text('Successful Sync'),
                trailing: Text('$successfulSync'),
              ),
              ListTile(
                title: const Text('Failed Sync'),
                trailing: Text('$failedSync'),
              ),
              ListTile(
                title: const Text('Active Conflicts'),
                trailing: Text('$conflicts'),
              ),
            ],
          ),
        );
      },
    );
  }
}
