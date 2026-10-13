import 'package:flutter/material.dart';

class CustomerPage extends StatelessWidget {
  const CustomerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final customers = [
      {'name': 'Budi Santoso', 'orders': '12 transaksi'},
      {'name': 'Sari Resto', 'orders': '8 transaksi'},
      {'name': 'Andi Wijaya', 'orders': '5 transaksi'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(customer['name']!),
              subtitle: Text(customer['orders']!),
            ),
          );
        },
      ),
    );
  }
}
