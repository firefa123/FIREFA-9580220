import 'package:flutter/material.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final menus = [
      {'name': 'Nasi Goreng Special', 'price': '25000', 'status': 'Available'},
      {'name': 'Es Teh', 'price': '8000', 'status': 'Available'},
      {'name': 'Ayam Geprek', 'price': '22000', 'status': 'Unavailable'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Menu Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menus.length,
        itemBuilder: (context, index) {
          final item = menus[index];
          return Card(
            child: ListTile(
              title: Text(item['name']!),
              subtitle: Text('Rp ${item['price']}'),
              trailing: Text(item['status']!),
            ),
          );
        },
      ),
    );
  }
}
