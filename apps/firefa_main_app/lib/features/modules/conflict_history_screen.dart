import 'package:flutter/material.dart';

/// Owner-facing history placeholder. The data layer can be connected to
/// FirefaConflictAuditStore without changing existing dashboard structure.
class FirefaConflictHistoryScreen extends StatelessWidget {
  const FirefaConflictHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conflict History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('Audit Resolution History'),
              subtitle: Text(
                'Riwayat penyelesaian konflik sinkronisasi akan tampil di sini.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Filter'),
              subtitle: Text('Aktif | Selesai | Tipe Konflik'),
            ),
          ),
        ],
      ),
    );
  }
}
