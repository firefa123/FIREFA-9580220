import 'package:flutter/material.dart';

import '../../controllers/pos_controller.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final controller = PosController();

  final products = const [
    {'name': 'Nasi Goreng', 'price': 20000},
    {'name': 'Burger', 'price': 25000},
    {'name': 'Coffee', 'price': 15000},
    {'name': 'Tea', 'price': 10000},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS')),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        controller.addItem(
                          product['name'] as String,
                          product['price'] as int,
                        );
                      });
                    },
                    child: Center(
                      child: Text('${product['name']}\nRp ${product['price']}'),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  const Text('Cart'),
                  Expanded(
                    child: ListView(
                      children: controller.cart
                          .map((item) => ListTile(
                                title: Text(item.name),
                                subtitle: Text('Qty ${item.quantity}'),
                                trailing: Text('Rp ${item.subtotal}'),
                              ))
                          .toList(),
                    ),
                  ),
                  Text('Total: Rp ${controller.total}'),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
