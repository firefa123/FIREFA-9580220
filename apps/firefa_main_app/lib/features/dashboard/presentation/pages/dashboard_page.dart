import 'package:flutter/material.dart';

import '../../../../shared/widgets/stat_card.dart';
import '../../../orders/presentation/pages/pos_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FIREFA'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selamat datang, Owner 👋',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Pantau bisnis kamu hari ini',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: const [
                StatCard(
                  title: 'Omzet Hari Ini',
                  value: 'Rp 5.250.000',
                  icon: Icons.payments,
                ),
                StatCard(
                  title: 'Transaksi',
                  value: '128 Order',
                  icon: Icons.receipt_long,
                ),
                StatCard(
                  title: 'Outlet Aktif',
                  value: '3 Outlet',
                  icon: Icons.store,
                ),
                StatCard(
                  title: 'Menu Terlaris',
                  value: 'Nasi Goreng',
                  icon: Icons.restaurant,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Action',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                _action(Icons.add_box, 'Tambah Menu'),
                _action(
                  Icons.point_of_sale,
                  'Kasir',
                  onPressed: () => _openPos(context),
                ),
                _action(Icons.people, 'Customer'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _action(
    IconData icon,
    String label, {
    VoidCallback? onPressed,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed ?? () {},
    );
  }

  void _openPos(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PosPage(),
      ),
    );
  }
}
