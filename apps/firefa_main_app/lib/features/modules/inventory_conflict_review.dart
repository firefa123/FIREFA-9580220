import 'package:flutter/material.dart';

import 'inventory_hybrid_sync.dart';

/// Review page for inventory mismatches. Decisions are intentionally handled
/// outside this view to avoid changing stock without explicit approval.
class InventoryConflictReview extends StatelessWidget {
  final InventoryConflictRecord conflict;

  const InventoryConflictReview({super.key, required this.conflict});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Conflict Review')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Item: ${conflict.itemName}'),
          const SizedBox(height: 12),
          Text('Local Stock: ${conflict.localStock}'),
          Text('Server Stock: ${conflict.serverStock}'),
          const SizedBox(height: 20),
          const Text('Resolution requires owner confirmation.'),
        ],
      ),
    );
  }
}
