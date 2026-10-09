import 'package:flutter/material.dart';

import '../../core/outlet/active_outlet_store.dart';

/// UI-06: honest, read-only placeholder until this module has a real store.
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  static const primary = Color(0xFF008F83);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final outlet = FirefaActiveOutletStore.instance;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu, color: primary, size: 23),
                Text('Menu Management',
                    style: TextStyle(
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Pengelolaan katalog dan kategori',
                style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 16 : 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 17, color: primary),
                      Text(outlet.selectedOutletName,
                          style: const TextStyle(
                              color: ink, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Belum tersedia',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.restaurant_menu,
                                color: primary, size: 34),
                          ),
                          const SizedBox(height: 18),
                          const Text('Pengelolaan menu belum tersedia',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          const Text('Katalog contoh pada POS belum terhubung dengan penyimpanan menu yang dapat diedit.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted, height: 1.5)),
                          const SizedBox(height: 20),
                          const Text(
                            'Local Only • Tidak ada sinkronisasi cloud',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
