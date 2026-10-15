import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'inventory_store.dart';
import 'menu_store.dart';

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
  final menuStore = FirefaMenuStore.instance;
  late final Future<void> ready;
  String itemQuery = '';
  String itemStatus = 'all';
  String itemUnit = 'all';
  String movementQuery = '';
  String movementType = 'all';
  DateTime? movementDate;

  @override
  void initState() {
    super.initState();
    ready = Future.wait([store.initialize(), menuStore.initialize()]).then((_) {});
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


  Future<void> setItemCost(FirefaInventoryItem item) async {
    if (!allowed || item.outletId != outlet.selectedOutletId) return;
    final controller = TextEditingController(text: item.unitCost.toStringAsFixed(0));
    final value = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Atur HPP ' + item.name),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(14)],
        decoration: InputDecoration(labelText: 'Harga beli per ' + item.unit + ' (Rp)', helperText: 'Bahan olahan dihitung dari resep produksinya.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.replaceAll(',', '.'))), child: const Text('Simpan')),
      ],
    ));
    controller.dispose();
    if (!mounted || value == null || !allowed || item.outletId != outlet.selectedOutletId) return;
    if (!store.setUnitCost(outletId: item.outletId, id: item.id, unitCost: value)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HPP tidak valid.')));
    }
  }

  Future<void> managePreparedRecipe() async {
    if (!allowed) return;
    final sourceOutlet = outlet.selectedOutletId;
    final items = store.forOutlet(sourceOutlet);
    final prepared = items.where((item) => item.isPreparedIngredient).toList();
    if (prepared.isEmpty || items.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tandai minimal satu barang sebagai bahan olahan dan siapkan bahan bakunya terlebih dahulu.')));
      return;
    }
    var targetId = prepared.first.id;
    var ingredientId = items.firstWhere((item) => item.id != targetId).id;
    final quantity = TextEditingController(text: '1');
    final yieldQty = TextEditingController(text: '1');
    final result = await showDialog<({String target, String ingredient, int quantity, int yieldQty})>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('Resep Bahan Olahan'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: targetId, isExpanded: true, decoration: const InputDecoration(labelText: 'Hasil olahan'),
            items: prepared.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name + ' (' + item.unit + ')'))).toList(),
            onChanged: (value) { if (value != null) refresh(() { targetId = value; if (ingredientId == targetId) ingredientId = items.firstWhere((item) => item.id != targetId).id; }); }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: ingredientId, isExpanded: true, decoration: const InputDecoration(labelText: 'Bahan yang dikonsumsi'),
            items: items.where((item) => item.id != targetId).map((item) => DropdownMenuItem(value: item.id, child: Text(item.name + ' (' + item.unit + ')'))).toList(),
            onChanged: (value) { if (value != null) refresh(() => ingredientId = value); }),
          const SizedBox(height: 10),
          TextField(controller: quantity, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: const InputDecoration(labelText: 'Kebutuhan bahan per batch (satuan stok)')),
          const SizedBox(height: 10),
          TextField(controller: yieldQty, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: const InputDecoration(labelText: 'Hasil olahan per batch (satuan stok)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (target: targetId, ingredient: ingredientId,
            quantity: int.tryParse(quantity.text) ?? 0, yieldQty: int.tryParse(yieldQty.text) ?? 0)), child: const Text('Simpan Resep')),
        ],
      )),
    );
    quantity.dispose(); yieldQty.dispose();
    if (!mounted || result == null || !allowed || sourceOutlet != outlet.selectedOutletId) return;
    if (!store.addPreparedRecipeLine(outletId: sourceOutlet, preparedItemId: result.target, ingredientId: result.ingredient,
      quantity: result.quantity, outputQuantity: result.yieldQty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resep olahan tidak valid. Pastikan jumlah bahan dan hasil lebih dari nol.')));
    }
  }

  Future<void> producePrepared() async {
    if (!allowed) return;
    final sourceOutlet = outlet.selectedOutletId;
    final recipes = store.preparedRecipesForOutlet(sourceOutlet);
    final prepared = store.forOutlet(sourceOutlet).where((item) => item.isPreparedIngredient &&
      recipes.any((line) => line.preparedItemId == item.id)).toList();
    if (prepared.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atur resep bahan olahan terlebih dahulu.')));
      return;
    }
    var selectedId = prepared.first.id;
    final batches = TextEditingController(text: '1');
    final result = await showDialog<({String id, int batches})>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Produksi Bahan Olahan'),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: selectedId, isExpanded: true, decoration: const InputDecoration(labelText: 'Bahan olahan'),
          items: prepared.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name + ' (' + item.unit + ')'))).toList(),
          onChanged: (value) { if (value != null) refresh(() => selectedId = value); }),
        const SizedBox(height: 12),
        TextField(controller: batches, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: const InputDecoration(labelText: 'Jumlah batch')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, (id: selectedId, batches: int.tryParse(batches.text) ?? 0)), child: const Text('Produksi')),
      ],
    )));
    batches.dispose();
    if (!mounted || result == null || !allowed || sourceOutlet != outlet.selectedOutletId) return;
    try {
      await store.producePreparedIngredient(outletId: sourceOutlet, preparedItemId: result.id, batches: result.batches);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produksi tersimpan. Stok bahan berkurang, hasil olahan bertambah, dan HPP diperbarui.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Produksi gagal: ' + error.toString())));
    }
  }

  Future<void> manageRecipe() async {
    if (!allowed) return;
    final sourceOutlet = outlet.selectedOutletId;
    final menus = menuStore.forOutlet(sourceOutlet)
        .where((menu) => menu.isActive)
        .map((menu) => (id: menu.id, name: menu.name))
        .toList();
    if (menus.isEmpty && menuStore.forOutlet(sourceOutlet).isEmpty) {
      menus.addAll(const [
        (id: 'P01', name: 'Cappuccino'),
        (id: 'P02', name: 'Cafe Latte'),
        (id: 'P03', name: 'Americano'),
        (id: 'P04', name: 'Matcha Latte'),
        (id: 'P05', name: 'Chocolate Ice'),
        (id: 'P06', name: 'Lemon Tea'),
        (id: 'P07', name: 'Nasi Goreng'),
        (id: 'P08', name: 'Chicken Katsu'),
        (id: 'P09', name: 'Beef Burger'),
        (id: 'P10', name: 'French Fries'),
        (id: 'P11', name: 'Chicken Wings'),
        (id: 'P12', name: 'Cheesecake'),
      ]);
    }
    final items = store.forOutlet(sourceOutlet);
    if (menus.isEmpty || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambahkan menu dan barang inventory terlebih dahulu untuk mengatur resep.')));
      return;
    }
    var menuId = menus.first.id;
    var ingredientId = items.first.id;
    final quantityController = TextEditingController(text: '1');
    final result = await showDialog<({String menuId, String ingredientId, int quantity})>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Atur Resep Menu'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: menuId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Menu POS'),
            items: menus.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
            onChanged: (value) { if (value != null) update(() => menuId = value); }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: ingredientId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Bahan inventory'),
            items: items.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (${i.unit})'))).toList(),
            onChanged: (value) { if (value != null) update(() => ingredientId = value); }),
          const SizedBox(height: 12),
          TextField(controller: quantityController, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: const InputDecoration(labelText: 'Kebutuhan bahan per 1 menu')),
          const SizedBox(height: 8),
          const Text('Simpan satu bahan per baris resep. Ulangi untuk bahan lain pada menu yang sama.', style: TextStyle(fontSize: 12, color: muted)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (menuId: menuId, ingredientId: ingredientId, quantity: int.tryParse(quantityController.text) ?? 0)), child: const Text('Simpan Resep')),
        ],
      )),
    );
    quantityController.dispose();
    if (!mounted || result == null || sourceOutlet != outlet.selectedOutletId || !allowed) return;
    if (!store.addRecipeLine(outletId: sourceOutlet, menuId: result.menuId, ingredientId: result.ingredientId, quantity: result.quantity)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resep tidak valid. Periksa menu, bahan, dan jumlah kebutuhan.')));
    }
  }

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

  Future<void> manage(FirefaInventoryItem item, String action) async {
    if (!allowed || item.outletId != outlet.selectedOutletId) return;
    final sourceOutlet = item.outletId;
    if (action == 'cost') { await setItemCost(item); return; }
    if (action == 'prepared') {
      final ok = store.setPreparedIngredient(outletId: sourceOutlet, id: item.id, prepared: !item.isPreparedIngredient);
      if (ok && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(item.isPreparedIngredient ? 'Status bahan olahan dinonaktifkan.' : 'Barang ditandai sebagai bahan olahan.')));
      return;
    }
    if (action == 'delete') {
      final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Hapus Barang?'),
        content: Text('Hapus ${item.name}? Riwayat stok tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ));
      if (!mounted || yes != true || !allowed || sourceOutlet != outlet.selectedOutletId) return;
      final reason = store.removalBlockReason(sourceOutlet, item.id);
      if (reason != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Barang tidak dapat dihapus: $reason'),
        ));
        return;
      }
      if (!store.remove(sourceOutlet, item.id)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Barang tidak dapat dihapus. Muat ulang data dan coba lagi.'),
        ));
      }
      return;
    }
    final name = TextEditingController(text: item.name);
    final amount = TextEditingController(text: action == 'edit' ? item.minimumStock.toString() : '');
    final note = TextEditingController();
    var unit = item.unit;
    var inputUnit = item.unit;
    var type = 'in';
    final result = await showDialog<({String name, String unit, String type, int amount, String note, String inputUnit})>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: Text(action == 'edit' ? 'Edit Barang' : 'Penyesuaian Stok'),
        content: SizedBox(width: 390, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action == 'edit') ...[
              TextField(controller: name, maxLength: 80, decoration: const InputDecoration(labelText: 'Nama barang')),
              DropdownButtonFormField<String>(
                initialValue: unit, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Satuan'),
                items: FirefaInventoryStore.units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) { if (v != null) refresh(() => unit = v); },
              ),
            ] else ...[
              Text('Stok saat ini: ${item.stock} ${item.unit}'),
              DropdownButtonFormField<String>(
                initialValue: inputUnit, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Satuan input (akan dikonversi)'),
                items: FirefaInventoryStore.units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) { if (v != null) refresh(() => inputUnit = v); },
              ),
              DropdownButtonFormField<String>(
                initialValue: type, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis perubahan'),
                items: const [
                  DropdownMenuItem(value: 'in', child: Text('Tambah')),
                  DropdownMenuItem(value: 'out', child: Text('Kurangi')),
                  DropdownMenuItem(value: 'correction', child: Text('Koreksi stok akhir')),
                ],
                onChanged: (v) { if (v != null) refresh(() => type = v); },
              ),
              TextField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'Keterangan')),
            ],
            TextField(controller: amount, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: InputDecoration(labelText: action == 'edit' ? 'Batas minimum' : type == 'correction' ? 'Stok akhir' : 'Jumlah'),
            ),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (
            name: name.text, unit: unit, type: type,
            amount: int.tryParse(amount.text) ?? -1, note: note.text, inputUnit: inputUnit,
          )), child: const Text('Simpan')),
        ],
      )),
    );
    name.dispose();
    amount.dispose();
    note.dispose();
    if (!mounted || result == null || !allowed || sourceOutlet != outlet.selectedOutletId) { return; }
    try {
      final success = action == 'edit'
        ? store.update(outletId: sourceOutlet, id: item.id, name: result.name, unit: result.unit, minimumStock: result.amount)
        : store.adjustConverted(outletId: sourceOutlet, id: item.id, type: result.type,
            amount: result.amount.toDouble(), inputUnit: result.inputUnit, note: result.note);
      if (!success) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan ditolak. Periksa nilai, stok, dan nama unik.')));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Konversi stok gagal: ' + error.toString())));
    }
  }

  String _csvCell(Object value) {
    final raw = value.toString();
    final safe = RegExp(r'^[=+@-]').hasMatch(raw) ? "'$raw" : raw;
    return '"${safe.replaceAll('"', '""')}"';
  }

  Future<void> copyCsv(List<FirefaInventoryItem> items, String outletName) async {
    final rows = <List<Object>>[
      ['Outlet', 'Nama Barang', 'Satuan', 'Stok', 'Minimum', 'Status'],
      for (final item in items)
        [outletName, item.name, item.unit, item.stock, item.minimumStock,
          item.isOutOfStock ? 'Habis' : item.isLowStock ? 'Rendah' : 'Aman'],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\\r\\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('CSV disalin. Tempel ke file .csv untuk menyimpan laporan.'),
    ));
  }

  Future<void> startOpname(FirefaInventoryItem item) async {
    if (!allowed || item.outletId != outlet.selectedOutletId) return;
    final sourceOutlet = item.outletId;
    final quantity = TextEditingController(text: item.stock.toString());
    final note = TextEditingController();
    final result = await showDialog<({int physical, String note})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock Opname: ${item.name}'),
        content: SizedBox(width: 380, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Text('Stok sistem: ${item.stock} ${item.unit}'),
            TextField(controller: quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: const InputDecoration(labelText: 'Stok fisik')),
            TextField(controller: note, maxLength: 200,
              decoration: const InputDecoration(labelText: 'Catatan pemeriksaan')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx,
            (physical: int.tryParse(quantity.text) ?? -1, note: note.text)),
            child: const Text('Catat Opname')),
        ],
      ),
    );
    quantity.dispose();
    note.dispose();
    if (!mounted || result == null || !allowed ||
        sourceOutlet != outlet.selectedOutletId) { return; }
    final ok = store.createOpname(outletId: sourceOutlet,
      itemId: item.id, physicalStock: result.physical, note: result.note);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Opname gagal: periksa jumlah atau selesaikan opname tertunda.'),
      ));
    }
  }

  Future<void> decideOpname(FirefaStockOpname record, bool approve) async {
    if (!allowed || record.outletId != outlet.selectedOutletId) return;
    final sourceOutlet = record.outletId;
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Setujui koreksi stok?' : 'Tolak stock opname?'),
        content: Text('${record.itemName}: sistem ${record.systemStock}, fisik ${record.physicalStock}, selisih ${record.difference}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Setujui' : 'Tolak')),
        ],
      ),
    );
    if (!mounted || confirmed != true || !allowed ||
        sourceOutlet != outlet.selectedOutletId) { return; }
    final ok = store.resolveOpname(outletId: sourceOutlet,
      opnameId: record.id, approve: approve);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Keputusan gagal. Stok mungkin sudah berubah; buat opname baru.'),
      ));
    }
  }

  Widget _metric(String label, int count, Color color) {
    return Container(
      width: 145, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24)),
      ]),
    );
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
        final history = store.historyForOutlet(outlet.selectedOutletId);
        final opnames = store.opnamesForOutlet(outlet.selectedOutletId);
        final filteredHistory = history.where((movement) {
          if (!movement.itemName.toLowerCase().contains(movementQuery.trim().toLowerCase())) return false;
          if (movementType != 'all' && movement.type != movementType) return false;
          if (movementDate != null) {
            final date = DateTime.tryParse(movement.timestamp);
            if (date == null || date.year != movementDate!.year ||
                date.month != movementDate!.month || date.day != movementDate!.day) { return false; }
          }
          return true;
        }).toList();
        final filteredItems = items.where((item) {
          if (!item.name.toLowerCase().contains(itemQuery.trim().toLowerCase())) return false;
          if (itemUnit != 'all' && item.unit != itemUnit) return false;
          if (itemStatus == 'empty' && !item.isOutOfStock) return false;
          if (itemStatus == 'low' && !item.isLowStock) return false;
          if (itemStatus == 'safe' && (item.isLowStock || item.isOutOfStock)) return false;
          return true;
        }).toList();
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
                    OutlinedButton.icon(onPressed: allowed ? manageRecipe : null, icon: const Icon(Icons.menu_book_outlined), label: const Text('Atur Resep POS')),
                    OutlinedButton.icon(onPressed: allowed ? managePreparedRecipe : null, icon: const Icon(Icons.restaurant_menu), label: const Text('Resep Olahan')),
                    OutlinedButton.icon(onPressed: allowed ? producePrepared : null, icon: const Icon(Icons.inventory_2_outlined), label: const Text('Produksi Olahan')),
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
                const Text('Inventory lokal • Resep POS aktif lokal • Cloud belum terhubung',
                    style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 14),
                const Text('Resep Menu POS', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (store.recipesForOutlet(outlet.selectedOutletId).isEmpty)
                  const Text('Belum ada resep. Checkout belum akan mengurangi stok sampai resep dibuat.', style: TextStyle(color: muted, fontSize: 12)),
                for (final recipe in store.recipesForOutlet(outlet.selectedOutletId))
                  Card(child: ListTile(
                    title: Text(menuStore.forOutlet(outlet.selectedOutletId).where((m) => m.id == recipe.menuId).map((m) => m.name).firstOrNull ?? const {'P01': 'Cappuccino', 'P02': 'Cafe Latte', 'P03': 'Americano', 'P04': 'Matcha Latte', 'P05': 'Chocolate Ice', 'P06': 'Lemon Tea', 'P07': 'Nasi Goreng', 'P08': 'Chicken Katsu', 'P09': 'Beef Burger', 'P10': 'French Fries', 'P11': 'Chicken Wings', 'P12': 'Cheesecake'}[recipe.menuId] ?? recipe.menuId),
                    subtitle: Text('${items.where((i) => i.id == recipe.ingredientId).map((i) => i.name).firstOrNull ?? recipe.ingredientId}: ${recipe.quantity} ${items.where((i) => i.id == recipe.ingredientId).map((i) => i.unit).firstOrNull ?? ''} per menu'),
                    trailing: allowed ? IconButton(tooltip: 'Hapus bahan dari resep', icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => store.removeRecipeLine(outletId: recipe.outletId, menuId: recipe.menuId, ingredientId: recipe.ingredientId)) : null,
                  )),
                const SizedBox(height: 18),
                Wrap(spacing: 12, runSpacing: 10, children: [
                  _metric('Total Barang', items.length, primary),
                  _metric('Stok Aman', items.length - low - empty, primary),
                  _metric('Stok Rendah', low, Colors.orange),
                  _metric('Stok Habis', empty, Colors.red),
                ]),
                if (low > 0)
                  Card(color: const Color(0xFFFFF7ED), child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Peringatan stok rendah', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9A3412))),
                      const SizedBox(height: 6),
                      for (final item in items.where((item) => item.isLowStock || item.isOutOfStock).take(8))
                        Text((item.isOutOfStock ? 'HABIS • ' : 'RENDAH • ') + item.name + ': ' + item.stock.toString() + ' ' + item.unit + ' (minimum ' + item.minimumStock.toString() + ')',
                          style: const TextStyle(fontSize: 12)),
                    ]),
                  )),
                const SizedBox(height: 14),
                const Text('HPP Resep Menu', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('HPP dihitung dari kuantitas resep × harga beli per satuan stok.', style: TextStyle(color: muted, fontSize: 12)),
                for (final menuId in store.recipesForOutlet(outlet.selectedOutletId).map((line) => line.menuId).toSet())
                  Card(child: ListTile(
                    title: Text(menuStore.forOutlet(outlet.selectedOutletId).where((menu) => menu.id == menuId).map((menu) => menu.name).firstOrNull ?? menuId),
                    subtitle: Text('HPP per porsi: Rp ' + store.hppForMenu(outletId: outlet.selectedOutletId, menuId: menuId).toStringAsFixed(0)),
                  )),
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  SizedBox(width: narrow ? constraints.maxWidth : 230,
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Cari barang', prefixIcon: Icon(Icons.search)),
                      onChanged: (value) => setState(() => itemQuery = value),
                    )),
                  DropdownButton<String>(
                    value: itemStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua status')),
                      DropdownMenuItem(value: 'safe', child: Text('Aman')),
                      DropdownMenuItem(value: 'low', child: Text('Stok Rendah')),
                      DropdownMenuItem(value: 'empty', child: Text('Habis')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => itemStatus = value);
                    },
                  ),
                  DropdownButton<String>(
                    value: itemUnit,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Semua satuan')),
                      ...FirefaInventoryStore.units.map((unit) =>
                        DropdownMenuItem(value: unit, child: Text(unit))),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => itemUnit = value);
                    },
                  ),
                ]),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin CSV (barang terfilter)'),
                  onPressed: outlet.canAccessOutlet(outlet.selectedOutletId)
                    ? () => copyCsv(filteredItems, outlet.selectedOutletName) : null,
                ),
                const SizedBox(height: 14),
                if (items.isNotEmpty && filteredItems.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('Tidak ada barang sesuai filter.')),
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
                if (filteredItems.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 950 ? 4
                          : constraints.maxWidth >= 650 ? 3
                          : narrow ? 1 : 2,
                      mainAxisExtent: 215,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
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
                            if (allowed)
                              Align(alignment: Alignment.centerRight, child: PopupMenuButton<String>(
                                tooltip: 'Kelola ${item.name}',
                                onSelected: (action) => action == 'opname'
                                  ? startOpname(item) : manage(item, action),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit Barang')),
                                  PopupMenuItem(value: 'adjust', child: Text('Penyesuaian Stok')),
                                  PopupMenuItem(value: 'cost', child: Text('Atur HPP / Harga Beli')),
                                  PopupMenuItem(value: 'prepared', child: Text(item.isPreparedIngredient ? 'Jadikan Bahan Baku' : 'Tandai Bahan Olahan')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus Barang')),
                                  PopupMenuItem(value: 'opname', child: Text('Stock Opname')),
                                ],
                              )),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                const Text('Stock Opname & Audit Trail',
                  style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (opnames.isEmpty)
                  const Text('Belum ada stock opname.', style: TextStyle(color: muted)),
                for (final record in opnames)
                  Card(child: Padding(padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(record.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Sistem: ${record.systemStock} • Fisik: ${record.physicalStock} • Selisih: ${record.difference}'),
                      Text('Status: ${record.status} • ${record.createdAt}'),
                      if (record.note.isNotEmpty) Text('Catatan: ${record.note}'),
                      if (record.resolvedAt != null) Text('Diputuskan: ${record.resolvedAt}'),
                      if (allowed && record.status == 'pending')
                        Wrap(spacing: 8, children: [
                          TextButton(onPressed: () => decideOpname(record, false),
                            child: const Text('Tolak')),
                          FilledButton(onPressed: () => decideOpname(record, true),
                            child: const Text('Setujui')),
                        ]),
                    ]),
                  )),
                const SizedBox(height: 24),
                const Text('Riwayat Perubahan Stok', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  SizedBox(width: narrow ? constraints.maxWidth : 230,
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Cari riwayat barang', prefixIcon: Icon(Icons.search)),
                      onChanged: (value) => setState(() => movementQuery = value),
                    )),
                  DropdownButton<String>(value: movementType, items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua pergerakan')),
                    DropdownMenuItem(value: 'in', child: Text('Tambah')),
                    DropdownMenuItem(value: 'out', child: Text('Kurangi')),
                    DropdownMenuItem(value: 'correction', child: Text('Koreksi')),
                  ], onChanged: (value) {
                    if (value != null) setState(() => movementType = value);
                  }),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(movementDate == null ? 'Pilih tanggal' :
                      '${movementDate!.day}/${movementDate!.month}/${movementDate!.year}'),
                    onPressed: () async {
                      final date = await showDatePicker(context: context,
                        initialDate: movementDate ?? DateTime.now(),
                        firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (date != null && mounted) setState(() => movementDate = date);
                    },
                  ),
                  if (movementDate != null)
                    TextButton(onPressed: () => setState(() => movementDate = null), child: const Text('Hapus tanggal')),
                ]),
                if (filteredHistory.isEmpty)
                  const Text('Tidak ada riwayat sesuai filter.', style: TextStyle(color: muted)),
                for (final movement in filteredHistory)
                  Card(child: ListTile(
                    title: Text('${movement.itemName} • ${movement.type == 'in' ? 'Tambah' : movement.type == 'out' ? 'Kurangi' : 'Koreksi'}'),
                    subtitle: Text('${movement.timestamp} • ${movement.before} → ${movement.after} • ${movement.note.isEmpty ? 'Tanpa keterangan' : movement.note}'),
                    trailing: Text('${movement.change > 0 ? '+' : ''}${movement.change}'),
                  )),
              ],
            );
          },
        );
      },
    );
  }
}
