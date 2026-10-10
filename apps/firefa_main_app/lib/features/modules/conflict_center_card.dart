import 'package:flutter/material.dart';

import 'conflict_store.dart';

/// Reusable owner dashboard card. It only observes conflict state and does not
/// change existing dashboard navigation or POS flows.
class FirefaConflictCenterCard extends StatelessWidget {
  final VoidCallback? onTap;

  const FirefaConflictCenterCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FirefaConflictStore.instance,
      builder: (context, _) {
        final count = FirefaConflictStore.instance.conflicts.length;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded),
            title: const Text('Conflict Center'),
            subtitle: Text(
              count == 0
                  ? 'Tidak ada konflik sinkronisasi'
                  : '$count konflik membutuhkan review',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );
      },
    );
  }
}
