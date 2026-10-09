import 'package:flutter/material.dart';

class OwnerStaffPage extends StatelessWidget {
  const OwnerStaffPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Staff Demo'),
            subtitle: Text('Role: Cashier • Status: Active'),
          ),
          ListTile(
            leading: Icon(Icons.add),
            title: Text('Tambah Staff'),
            subtitle: Text('Tambahkan pengguna dan atur role'),
          ),
        ],
      ),
    );
  }
}
