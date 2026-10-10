import 'package:flutter/material.dart';

class CashierDashboard extends StatelessWidget {
  const CashierDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cashier Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        Text('Transaction workspace'),
        Text('• New order\n• Payment\n• Active transactions\n• Receipt printing'),
      ],
    );
  }
}
