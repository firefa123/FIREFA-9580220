import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'inventory_store.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const primary = Color(0xFF008F83);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  final outlet = FirefaActiveOutletStore.instance;
  final store = FirefaInventoryStore.instance;
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
      FirefaAccess.can(outlet.role, FirefaPermission.inventoryManage) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

  Future<void> addItem() async {
    if (!allowed) return;
    final sourceOutlet = outlet.selectedOutletId;
    final nameController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final minimumController = TextEditingController(text: '0');
    var unit = FirefaInventoryStore.units.first;
    final input = await showDialog<({String name, String unit, int stock, int minimum})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Tambah Barang Stok'),
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
                      labelText: 'Nama barang',
                      hintText: 'Contoh: Biji Kopi Arabika',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Satuan'),
                    items: FirefaInventoryStore.units.map((value) =>
                        DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value != null) update(() => unit = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Stok awal',
                      hintText: 'Contoh: 25',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minimumController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Batas minimum stok',
                      hintText: 'Contoh: 10',
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
              style: FilledButton.styleFrom(backgroundColor: primary),
              onPressed: () => Navigator.pop(dialogContext, (
                name: nameController.text,
                unit: unit,
                stock: int.tryParse(stockController.text) ?? -1,
                minimum: int.tryParse(minimumController.text) ?? -1,
              )),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    stockController.dispose();
    minimumController.dispose();
    if (!mounted || input == null) return;
    if (!allowed || sourceOutlet != outlet.selectedOutletId) return;
    if (!store.add(
      outletId: sourceOutlet,
      name: input.name,
      unit: input.unit,
      stock: input.stock,
      minimumStock: input.minimum,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Periksa nama barang (unik per outlet), satuan, stok awal, dan batas minimum.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Gagal memuat inventory lokal. Data lama tidak diubah.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = store.forOutlet(outlet.selectedOutletId);
        final low = items.where((item) => item.isLowStock).length;
        final empty = items.where((item) => item.isOutOfStock).length;
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
                    const Icon(Icons.inventory_2, color: primary),
                    Text('Inventory Management', style: TextStyle(
                      color: ink, fontWeight: FontWeight.bold,
                      fontSize: narrow ? 20 : 23,
                    )),
                    FilledButton.icon(
                      onPressed: allowed ? addItem : null,
                      style: FilledButton.styleFrom(backgroundColor: primary),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Barang'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${outlet.selectedOutletName} • ${items.length} barang • $low stok rendah • $empty habis',
                    style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 8),
                const Text('Inventory lokal • Belum terhubung ke POS, resep, atau cloud',
                    style: TextStyle(color: muted, fontSize: 12)),
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
                        Icon(Icons.inventory_2_outlined, size: 42, color: muted),
                        SizedBox(height: 12),
                        Text('Belum ada barang stok',
                            style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('Tambahkan barang pertama untuk outlet ini.',
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
                      crossAxisCount: constraints.maxWidth >= 950 ? 4
                          : constraints.maxWidth >= 650 ? 3
                          : narrow ? 1 : 2,
                      mainAxisExtent: 165,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final status = item.isOutOfStock ? 'Habis'
                          : item.isLowStock ? 'Stok Rendah' : 'Aman';
                      final statusColor = item.isOutOfStock ? Colors.red
                          : item.isLowStock ? Colors.orange.shade800 : primary;
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16, color: ink, fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(height: 9),
                            Text('Stok: ${item.stock} ${item.unit}',
                                style: const TextStyle(color: ink)),
                            Text('Minimum: ${item.minimumStock} ${item.unit}',
                                style: const TextStyle(color: muted, fontSize: 12)),
                            const Spacer(),
                            Text(status, style: TextStyle(
                              color: statusColor, fontWeight: FontWeight.w700,
                            )),
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
