import 'package:flutter/material.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = [
      {'id': '#00125', 'table': 'Meja 5', 'status': 'Preparing', 'total': 'Rp 85.000'},
      {'id': '#00126', 'table': 'Take Away', 'status': 'Completed', 'total': 'Rp 45.000'},
      {'id': '#00127', 'table': 'Meja 2', 'status': 'Waiting', 'total': 'Rp 120.000'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(order['id']!),
              subtitle: Text('${order['table']} • ${order['status']}'),
              trailing: Text(order['total']!),
            ),
          );
        },
      ),
    );
  }
}
