import 'package:flutter/material.dart';

class TopSellingCard extends StatelessWidget {
  const TopSellingCard({super.key});

  static const Color primary = Color(0xFF009688);
  static const Color dark = Color(0xFF172B4D);
  static const Color muted = Color(0xFF64748B);

  static const List<_MenuData> _items = [
    _MenuData('Nasi Goreng Spesial', '145 terjual', 0.90),
    _MenuData('Ayam Geprek', '118 terjual', 0.73),
    _MenuData('Es Kopi Susu', '96 terjual', 0.60),
    _MenuData('Mie Goreng', '82 terjual', 0.51),
    _MenuData('Es Teh Manis', '74 terjual', 0.46),
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
            'Menu dengan penjualan tertinggi',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 26),
          for (int i = 0; i < _items.length; i++) ...[
            _buildMenuItem(i + 1, _items[i]),
            if (i != _items.length - 1) const SizedBox(height: 25),
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
