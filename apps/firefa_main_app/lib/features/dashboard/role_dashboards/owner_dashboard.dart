import 'package:flutter/material.dart';

import '../widgets/sync_status_card.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Owner Dashboard',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        SyncStatusCard(),
        SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _OwnerCard(title: 'Revenue', icon: Icons.payments_outlined),
            _OwnerCard(title: 'Orders', icon: Icons.receipt_long_outlined),
            _OwnerCard(title: 'Outlet Performance', icon: Icons.store_outlined),
            _OwnerCard(title: 'Reports', icon: Icons.analytics_outlined),
          ],
        ),
      ],
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const _OwnerCard({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 180,
        height: 100,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              Spacer(),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}
