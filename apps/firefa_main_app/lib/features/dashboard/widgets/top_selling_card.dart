import 'package:flutter/material.dart';
import '../../modules/order_models.dart';

class TopSellingCard extends StatelessWidget {
  const TopSellingCard({super.key, required this.orders});
  final List<FirefaOrder> orders;

  static const Color primary = Color(0xFF008F83);
  static const Color dark = Color(0xFF172B4D);
  static const Color muted = Color(0xFF64748B);

  List<_MenuData> get items {
    final quantities = <String, int>{};
    for (final order in orders) {
      if (order.paymentStatus != FirefaPaymentStatus.paid ||
          order.status == FirefaOrderStatus.cancelled) {
        continue;
      }
      for (final item in order.items) {
        quantities.update(item.productName, (count) => count + item.quantity,
            ifAbsent: () => item.quantity);
      }
    }
    final sorted = quantities.entries.toList()
      ..sort((a, b) {
        final quantity = b.value.compareTo(a.value);
        return quantity != 0 ? quantity : a.key.compareTo(b.key);
      });
    final highest = sorted.isEmpty ? 1 : sorted.first.value;
    return sorted.take(5).map((entry) => _MenuData(
      entry.key, '${entry.value} terjual', entry.value / highest,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topItems = items;
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
                  'Top Selling Menu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
              ),
              Icon(Icons.restaurant_menu_outlined, color: muted),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Produk dari pesanan Paid lokal',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 26),
          if (topItems.isEmpty)
            const Text('Belum ada produk terjual dari pesanan Paid.',
                style: TextStyle(color: muted)),
          for (int i = 0; i < topItems.length; i++) ...[
            _buildMenuItem(i + 1, topItems[i]),
            if (i != topItems.length - 1) const SizedBox(height: 25),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(int rank, _MenuData item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(item.sold, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: item.progress,
            minHeight: 7,
            backgroundColor: const Color(0xFFE8EDF2),
            valueColor: const AlwaysStoppedAnimation<Color>(primary),
          ),
        ),
      ],
    );
  }
}

class _MenuData {
  final String name;
  final String sold;
  final double progress;

  const _MenuData(this.name, this.sold, this.progress);
}
