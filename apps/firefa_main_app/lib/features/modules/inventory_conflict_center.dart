import 'package:flutter/material.dart';

/// Inventory conflict entry point for owner monitoring.
/// This widget is intentionally read-only and does not alter stock data.
class FirefaInventoryConflictCenter extends StatelessWidget {
  final int conflictCount;
  final VoidCallback? onReview;

  const FirefaInventoryConflictCenter({
    super.key,
    required this.conflictCount,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Inventory Conflict Center'),
        subtitle: Text(
          conflictCount == 0
              ? 'Stok tersinkronisasi dengan aman'
              : '$conflictCount item membutuhkan review',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: conflictCount == 0 ? null : onReview,
      ),
    );
  }
}
