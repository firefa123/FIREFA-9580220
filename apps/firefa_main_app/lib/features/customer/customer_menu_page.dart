import 'package:flutter/material.dart';

import 'customer_cart_store.dart';

class CustomerMenuPage extends StatelessWidget {
  const CustomerMenuPage({super.key});

  static const products = [
    ('P01', 'Cappuccino', 28000),
    ('P02', 'Cafe Latte', 30000),
    ('P03', 'Americano', 24000),
  ];

  @override
  Widget build(BuildContext context) {
    final cart = FirefaCustomerCartStore.instance;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Customer Menu',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        for (final product in products)
          Card(
            child: ListTile(
              title: Text(product.$2),
              subtitle: Text('Rp ${product.$3}'),
              trailing: FilledButton(
                onPressed: () {
                  cart.add(CustomerCartItem(
                    productId: product.$1,
                    name: product.$2,
                    price: product.$3,
                  ));
                },
                child: const Text('Add'),
              ),
            ),
          ),
      ],
    );
  }
}
