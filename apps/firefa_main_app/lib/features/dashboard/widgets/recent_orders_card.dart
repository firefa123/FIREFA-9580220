import 'package:flutter/material.dart';

class RecentOrdersCard extends StatelessWidget {
  const RecentOrdersCard({super.key});

  static const Color dark = Color(0xFF172B4D);
  static const Color muted = Color(0xFF64748B);

  static const List<_OrderData> _orders = [
    _OrderData('#ORD-1048', 'Meja 05', '10:42', 'Rp 185.000', 'Completed'),
    _OrderData('#ORD-1047', 'Takeaway', '10:38', 'Rp 92.000', 'Preparing'),
    _OrderData('#ORD-1046', 'Meja 12', '10:31', 'Rp 245.000', 'Pending'),
    _OrderData('#ORD-1045', 'Delivery', '10:25', 'Rp 138.000', 'Completed'),
    _OrderData('#ORD-1044', 'Meja 03', '10:18', 'Rp 76.000', 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF2)),
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
                    color: dark,
                  ),
                ),
              ),
              Icon(Icons.receipt_long_outlined, color: muted),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Aktivitas pesanan terbaru',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < _orders.length; i++) ...[
            _buildOrder(_orders[i]),
            if (i != _orders.length - 1)
              const Divider(height: 24, color: Color(0xFFEDF1F5)),
          ],
        ],
      ),
    );
  }

  Widget _buildOrder(_OrderData order) {
    Color statusColor;
    Color statusBackground;

    switch (order.status) {
      case 'Completed':
        statusColor = const Color(0xFF047857);
        statusBackground = const Color(0xFFD1FAE5);
        break;

      case 'Preparing':
        statusColor = const Color(0xFFB45309);
        statusBackground = const Color(0xFFFEF3C7);
        break;

      default:
        statusColor = const Color(0xFF475569);
        statusBackground = const Color(0xFFF1F5F9);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.id,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.type} • ${order.time}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        );

        final amountAndStatus = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              order.amount,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: dark,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: amountAndStatus),
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

class _OrderData {
  final String id;
  final String type;
  final String time;
  final String amount;
  final String status;

  const _OrderData(this.id, this.type, this.time, this.amount, this.status);
}
