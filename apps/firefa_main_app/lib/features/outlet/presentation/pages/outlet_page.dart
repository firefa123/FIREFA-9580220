import 'package:flutter/material.dart';

class OutletPage extends StatelessWidget {
  const OutletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final outlets = [
      {'name': 'Outlet Pusat', 'status': 'Active', 'location': 'Jakarta'},
      {'name': 'Outlet Cabang 1', 'status': 'Active', 'location': 'Surabaya'},
      {'name': 'Outlet Cabang 2', 'status': 'Inactive', 'location': 'Bandung'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Outlet Management')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: outlets.length,
        itemBuilder: (context, index) {
          final outlet = outlets[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.store),
              title: Text(outlet['name']!),
              subtitle: Text(outlet['location']!),
              trailing: Text(outlet['status']!),
            ),
          );
        },
      ),
    );
  }
}
