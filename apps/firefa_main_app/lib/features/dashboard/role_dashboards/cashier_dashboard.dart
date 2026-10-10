import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CashierDashboard extends StatelessWidget {
  const CashierDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cashier Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ringkasan operasional kasir hari ini',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CashierMetricCard(
                title: 'Transactions',
                value: '42',
                caption: 'Hari ini',
                icon: Icons.receipt_long_outlined,
              ),
              _CashierMetricCard(
                title: 'Revenue',
                value: 'Rp 3.240.000',
                caption: 'Penjualan hari ini',
                icon: Icons.payments_outlined,
              ),
              _CashierMetricCard(
                title: 'Active Orders',
                value: '8',
                caption: 'Sedang diproses',
                icon: Icons.pending_actions_outlined,
              ),
              _CashierMetricCard(
                title: 'Available Tables',
                value: '5',
                caption: 'Siap digunakan',
                icon: Icons.table_bar_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _CashierWorkspaceCard(),
        ],
      ),
    );
  }
}

class _CashierMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;

  const _CashierMetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashierWorkspaceCard extends StatelessWidget {
  const _CashierWorkspaceCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cashier Workspace',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gunakan menu navigasi untuk membuka POS, memantau order, dan mengelola meja.',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _WorkspaceItem(
                  icon: Icons.point_of_sale_outlined,
                  title: 'POS',
                  description: 'Buat order dan proses pembayaran',
                ),
                _WorkspaceItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders',
                  description: 'Pantau status pesanan aktif',
                ),
                _WorkspaceItem(
                  icon: Icons.table_bar_outlined,
                  title: 'Tables',
                  description: 'Lihat dan atur ketersediaan meja',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _WorkspaceItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
