import 'package:flutter/material.dart';

import 'conflict_store.dart';
import 'conflict_resolution_engine.dart';

/// Review-only screen for owner/admin conflict handling.
/// It intentionally does not apply changes automatically.
class FirefaConflictReviewScreen extends StatelessWidget {
  const FirefaConflictReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FirefaConflictStore.instance,
      builder: (context, _) {
        final conflicts = FirefaConflictStore.instance.conflicts;
        return Scaffold(
          appBar: AppBar(title: const Text('Conflict Review')),
          body: conflicts.isEmpty
              ? const Center(child: Text('Tidak ada konflik'))
              : ListView.builder(
                  itemCount: conflicts.length,
                  itemBuilder: (context, index) {
                    final conflict = conflicts[index];
                    final plan = const FirefaConflictResolutionEngine()
                        .createPlan(conflict);
                    return Card(
                      child: ExpansionTile(
                        title: Text(conflict.kind.name),
                        subtitle: Text('Order: ${conflict.orderId}'),
                        children: [
                          ListTile(
                            title: const Text('Rekomendasi'),
                            subtitle: Text(plan.recommended.name),
                          ),
                          ListTile(
                            title: const Text('Local Snapshot'),
                            subtitle: Text(conflict.localSnapshot.toString()),
                          ),
                          ListTile(
                            title: const Text('Server Snapshot'),
                            subtitle: Text(conflict.serverSnapshot.toString()),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
