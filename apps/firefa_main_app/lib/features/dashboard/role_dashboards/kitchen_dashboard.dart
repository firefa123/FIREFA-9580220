import 'package:flutter/material.dart';

class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kitchen / Bar Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        Text('Kitchen queue'),
        Text('• New orders\n• Preparing\n• Ready to serve'),
      ],
    );
  }
}
