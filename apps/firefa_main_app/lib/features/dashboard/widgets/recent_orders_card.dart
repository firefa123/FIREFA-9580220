import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../modules/order_models.dart';

/// Read-only, outlet-scoped view. Orders are supplied by the dashboard.
class RecentOrdersCard extends StatelessWidget {
  final List<FirefaOrder> orders;

  const RecentOrdersCard({super.key, this.orders = const []});

  String _rupiah(int value) =>
      'Rp ${value.toString().replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (_) => '.')}';

  @override
  Widget build(BuildContext context) {
    final latest = orders.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visible = latest.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.receipt_long_outlined,
                  color: AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '5 pesanan terbaru dari outlet aktif • Data lokal',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada pesanan di outlet ini. Buat pesanan melalui POS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          for (int i = 0; i < visible.length; i++) ...[
            _buildOrder(visible[i]),
            if (i != visible.length - 1)
              const Divider(height: 24, color: AppTheme.border),
          ],
        ],
      ),
    );
  }

  Widget _buildOrder(FirefaOrder order) {
    final statusColor = switch (order.status) {
      FirefaOrderStatus.completed => const Color(0xFF047857),
      FirefaOrderStatus.cancelled => const Color(0xFFB91C1C),
      FirefaOrderStatus.preparing => const Color(0xFFB45309),
      _ => AppTheme.primary,
    };
    final local = order.createdAt.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final type = order.tableId == null
        ? order.orderType
        : '${order.orderType} • Meja ${order.tableId}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.id,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('$type • $time',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        );
        final amountAndStatus = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_rupiah(order.total),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.status.label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 10),
              Align(
                  alignment: Alignment.centerRight,
                  child: amountAndStatus),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 12),
            amountAndStatus,
          ],
        );
      },
    );
  }
}
