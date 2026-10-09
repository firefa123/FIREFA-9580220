import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'menu_store.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const primary = Color(0xFF008F83);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  final outlet = FirefaActiveOutletStore.instance;
  final store = FirefaMenuStore.instance;
  late final Future<void> ready;

  @override
  void initState() {
    super.initState();
    ready = store.initialize();
    outlet.addListener(_refresh);
    store.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    outlet.removeListener(_refresh);
    store.removeListener(_refresh);
    super.dispose();
  }

  bool get allowed =>
      FirefaAccess.can(outlet.role, FirefaPermission.menuManage) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

  String rupiah(int amount) => 'Rp ${amount.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

  Future<void> addMenu() async {
    if (!allowed) return;
    final sourceOutlet = outlet.selectedOutletId;
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    var category = FirefaMenuStore.categories.first;
    final input = await showDialog<({String name, String category, int price})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Tambah Menu'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Nama menu',
                      hintText: 'Contoh: Es Kopi Susu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: FirefaMenuStore.categories
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) update(() => category = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rp)',
                      hintText: 'Contoh: 28000',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                name: nameController.text,
                category: category,
                price: int.tryParse(priceController.text) ?? 0,
              )),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    priceController.dispose();
    if (!mounted || input == null) return;
    if (!allowed || sourceOutlet != outlet.selectedOutletId) return;
    if (!store.add(
      outletId: sourceOutlet,
      name: input.name,
      category: input.category,
      price: input.price,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nama harus unik per outlet, kategori valid, dan harga lebih dari Rp 0.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Gagal memuat katalog lokal. Data lama tidak diubah.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = store.forOutlet(outlet.selectedOutletId);
        final active = items.where((item) => item.isActive).length;
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.restaurant_menu, color: primary),
                    const Text('Menu Management',
                        style: TextStyle(
                          color: ink, fontWeight: FontWeight.bold, fontSize: 21,
                        )),
                    FilledButton.icon(
                      onPressed: allowed ? addMenu : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Menu'),
                      style: FilledButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${outlet.selectedOutletName} • ${items.length} menu • $active aktif',
                    style: const TextStyle(color: muted)),
                const SizedBox(height: 8),
                const Text(
                  'Katalog lokal • Belum terhubung dengan produk POS, checkout, atau cloud',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.restaurant_menu_outlined, size: 40, color: muted),
                        SizedBox(height: 12),
                        Text('Belum ada menu lokal',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('Tambahkan menu untuk outlet ini. Produk contoh POS tetap terpisah.',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                if (items.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 950
                          ? 4
                          : constraints.maxWidth >= 650
                              ? 3
                              : narrow
                                  ? 1
                                  : 2,
                      mainAxisExtent: 174,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16, color: ink, fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(height: 5),
                            Text(item.category, style: const TextStyle(color: muted)),
                            const SizedBox(height: 5),
                            Text(rupiah(item.price),
                                style: const TextStyle(
                                  color: primary, fontWeight: FontWeight.w700,
                                )),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.isActive ? 'Aktif' : 'Nonaktif',
                                    style: TextStyle(
                                      color: item.isActive ? primary : muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: item.isActive,
                                  activeThumbColor: primary,
                                  onChanged: allowed
                                      ? (value) => store.setActive(
                                            outlet.selectedOutletId, item.id, value,
                                          )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
