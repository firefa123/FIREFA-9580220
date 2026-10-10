import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manager Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pantau operasional outlet secara real-time',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ManagerMetricCard(
                title: 'Active Orders',
                value: '18',
                caption: 'Sedang berjalan',
                icon: Icons.receipt_long_outlined,
              ),
              _ManagerMetricCard(
                title: 'Shift Revenue',
                value: 'Rp 6.840.000',
                caption: 'Pendapatan shift',
                icon: Icons.payments_outlined,
              ),
              _ManagerMetricCard(
                title: 'Kitchen Queue',
                value: '12',
                caption: 'Pesanan diproses',
                icon: Icons.restaurant_outlined,
              ),
              _ManagerMetricCard(
                title: 'Table Occupancy',
                value: '74%',
                caption: 'Meja terpakai',
                icon: Icons.table_restaurant_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _OperationalOverview(),
          const SizedBox(height: 24),
          const _ManagerAlerts(),
        ],
      ),
    );
  }
}

class _ManagerMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;

  const _ManagerMetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
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
                  color: AppTheme.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary),
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationalOverview extends StatelessWidget {
  const _OperationalOverview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operational Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const _StatusRow(
              icon: Icons.local_fire_department_outlined,
              title: 'Kitchen',
              value: '12 orders preparing',
              status: 'Busy',
            ),
            const Divider(height: 24),
            const _StatusRow(
              icon: Icons.local_bar_outlined,
              title: 'Bar',
              value: '7 drinks waiting',
              status: 'Normal',
            ),
            const Divider(height: 24),
            const _StatusRow(
              icon: Icons.table_bar_outlined,
              title: 'Tables',
              value: '14 occupied • 5 available',
              status: '74%',
            ),
            const Divider(height: 24),
            const _StatusRow(
              icon: Icons.cloud_sync_outlined,
              title: 'Offline Sync',
              value: '2 transactions waiting',
              status: 'Pending',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String status;

  const _StatusRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryTint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagerAlerts extends StatelessWidget {
  const _ManagerAlerts();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manager Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            const _AlertItem(
              icon: Icons.inventory_2_outlined,
              title: 'Low stock',
              description: '3 inventory items perlu perhatian',
            ),
            const SizedBox(height: 12),
            const _AlertItem(
              icon: Icons.schedule_outlined,
              title: 'Long preparation time',
              description: '2 order melewati target waktu dapur',
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _AlertItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
