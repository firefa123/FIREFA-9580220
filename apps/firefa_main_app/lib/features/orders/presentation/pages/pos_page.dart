import 'package:flutter/material.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final products = const [
    {'name': 'Nasi Goreng', 'price': 20000},
    {'name': 'Burger', 'price': 25000},
    {'name': 'Coffee', 'price': 15000},
    {'name': 'Tea', 'price': 10000},
  ];

  final cart = <Map<String, dynamic>>[];

  int get total => cart.fold(0, (sum, item) => sum + (item['price'] as int));

  void addProduct(Map<String, dynamic> product) {
    setState(() => cart.add(product));
  }

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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: InkWell(
                    onTap: () => addProduct(product),
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
                    child: ListView.builder(
                      itemCount: cart.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(cart[index]['name']),
                        subtitle: Text('Rp ${cart[index]['price']}'),
                      ),
                    ),
                  ),
                  Text('Total: Rp $total'),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
