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
  String itemQuery = '';
  String itemStatus = 'all';
  String itemUnit = 'all';
  String movementQuery = '';
  String movementType = 'all';
  DateTime? movementDate;

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

  Future<void> manage(FirefaInventoryItem item, String action) async {
    if (!allowed || item.outletId != outlet.selectedOutletId) return;
    final sourceOutlet = item.outletId;
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
      store.remove(sourceOutlet, item.id);
      return;
    }
    final name = TextEditingController(text: item.name);
    final amount = TextEditingController(text: action == 'edit' ? item.minimumStock.toString() : '');
    final note = TextEditingController();
    var unit = item.unit;
    var type = 'in';
    final result = await showDialog<({String name, String unit, String type, int amount, String note})>(
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
            amount: int.tryParse(amount.text) ?? -1, note: note.text,
          )), child: const Text('Simpan')),
        ],
      )),
    );
    name.dispose();
    amount.dispose();
    note.dispose();
    if (!mounted || result == null || !allowed || sourceOutlet != outlet.selectedOutletId) return;
    final success = action == 'edit'
      ? store.update(outletId: sourceOutlet, id: item.id, name: result.name, unit: result.unit, minimumStock: result.amount)
      : store.adjust(outletId: sourceOutlet, id: item.id, type: result.type, amount: result.amount, note: result.note);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan ditolak. Periksa nilai, stok, dan nama unik.')));
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
        final filteredHistory = history.where((movement) {
          if (!movement.itemName.toLowerCase().contains(movementQuery.trim().toLowerCase())) return false;
          if (movementType != 'all' && movement.type != movementType) return false;
          if (movementDate != null) {
            final date = DateTime.tryParse(movement.timestamp);
            if (date == null || date.year != movementDate!.year ||
                date.month != movementDate!.month || date.day != movementDate!.day) return false;
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
                Wrap(spacing: 12, runSpacing: 10, children: [
                  _metric('Total Barang', items.length, primary),
                  _metric('Stok Aman', items.length - low - empty, primary),
                  _metric('Stok Rendah', low, Colors.orange),
                  _metric('Stok Habis', empty, Colors.red),
                ]),
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
                                onSelected: (action) => manage(item, action),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit Barang')),
                                  PopupMenuItem(value: 'adjust', child: Text('Penyesuaian Stok')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus Barang')),
                                ],
                              )),
                          ],
                        ),
                      );
                    },
                  ),
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
