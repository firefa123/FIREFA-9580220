import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'inventory_store.dart';
import 'purchase_order_store.dart';
import 'supplier_store.dart';

class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  static const primary = Color(0xFF008F83);
  final outlet = FirefaActiveOutletStore.instance;
  final orders = FirefaPurchaseOrderStore.instance;
  final suppliers = FirefaSupplierStore.instance;
  final inventory = FirefaInventoryStore.instance;
  late final Future<void> ready;
  String filter = 'all';
  String supplierFilter = 'all';
  String search = '';
  DateTimeRange? dateRange;

  bool get allowed =>
      FirefaAccess.can(outlet.role, FirefaPermission.inventoryManage) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

  @override
  void initState() {
    super.initState();
    ready = Future.wait([
      orders.initialize(), suppliers.initialize(), inventory.initialize(),
    ]).then((_) {});
    outlet.addListener(_refresh);
    orders.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    outlet.removeListener(_refresh);
    orders.removeListener(_refresh);
    super.dispose();
  }

  Future<void> createOrder() async {
    if (!allowed) {
      return;
    }
    final sourceOutlet = outlet.selectedOutletId;
    final supplierOptions = suppliers.forOutlet(sourceOutlet)
        .where((supplier) => supplier.isActive).toList();
    final itemOptions = inventory.forOutlet(sourceOutlet);
    if (supplierOptions.isEmpty || itemOptions.isEmpty) {
      _message('Buat supplier aktif dan barang inventory terlebih dahulu.');
      return;
    }
    String supplierId = supplierOptions.first.id;
    String itemId = itemOptions.first.id;
    final quantity = TextEditingController(text: '1');
    final cost = TextEditingController(text: '0');
    final note = TextEditingController();
    final result = await showDialog<({String supplierId, String itemId,
      int quantity, int unitCost, String note})>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Buat Purchase Order'),
        content: SizedBox(width: 430, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: supplierId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Supplier aktif'),
              items: supplierOptions.map((supplier) => DropdownMenuItem(
                value: supplier.id, child: Text(supplier.name),
              )).toList(),
              onChanged: (value) {
                if (value != null) update(() => supplierId = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: itemId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Barang inventory'),
              items: itemOptions.map((item) => DropdownMenuItem(
                value: item.id, child: Text('${item.name} (${item.unit})'),
              )).toList(),
              onChanged: (value) {
                if (value != null) update(() => itemId = value);
              },
            ),
            TextField(controller: quantity, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah pesan')),
            TextField(controller: cost, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga satuan (Rp)')),
            TextField(controller: note, maxLength: 200,
              decoration: const InputDecoration(labelText: 'Catatan')),
          ]),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (
            supplierId: supplierId, itemId: itemId,
            quantity: int.tryParse(quantity.text) ?? -1,
            unitCost: int.tryParse(cost.text) ?? -1,
            note: note.text,
          )), child: const Text('Buat PO')),
        ],
      )),
    );
    quantity.dispose();
    cost.dispose();
    note.dispose();
    if (!mounted || result == null || !allowed ||
        sourceOutlet != outlet.selectedOutletId) {
      return;
    }
    if (!orders.create(
      outletId: sourceOutlet, supplierId: result.supplierId,
      itemId: result.itemId, quantity: result.quantity,
      unitCost: result.unitCost, note: result.note,
    )) {
      _message('Gagal membuat PO. Periksa supplier, barang, dan jumlah.');
    }
  }

  Future<void> decide(FirefaPurchaseOrder po, bool receive) async {
    if (!allowed || po.outletId != outlet.selectedOutletId) {
      return;
    }
    final sourceOutlet = po.outletId;
    final controller = TextEditingController(
      text: po.remainingQuantity.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(receive ? 'Terima barang' : 'Batalkan PO?'),
        content: receive
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Sisa pesanan: ${po.remainingQuantity} ${po.unit} ${po.itemName}'),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah diterima'),
                ),
              ])
            : Text('Batalkan sisa pesanan ${po.id}? Stok yang sudah diterima tidak berubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Kembali')),
          FilledButton(onPressed: () => Navigator.pop(
            ctx, receive ? (int.tryParse(controller.text) ?? -1) : 0,
          ), child: Text(receive ? 'Terima Barang' : 'Batalkan Sisa')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null || !allowed ||
        sourceOutlet != outlet.selectedOutletId) {
      return;
    }
    final ok = receive
        ? orders.receive(
            outletId: sourceOutlet, orderId: po.id, quantity: result)
        : orders.cancel(outletId: sourceOutlet, orderId: po.id);
    if (!ok) {
      _message('Operasi gagal. Periksa sisa pesanan, stok, dan satuan barang.');
    }
  }

  String _csvCell(String value) {
    final safe = value.replaceAll('"', '""');
    final guarded = RegExp(r'^[=+@\\-]').hasMatch(safe) ? "'$safe" : safe;
    return '"$guarded"';
  }

  Future<void> _copyCsv(List<FirefaPurchaseOrder> rows) async {
    if (!allowed) return;
    final lines = <String>[
      'PO ID,Outlet ID,Supplier,Barang,Satuan,Jumlah Pesan,Jumlah Diterima,Sisa,Harga Satuan,Nilai Pesanan,Nilai Diterima,Status,Tanggal PO,Terakhir Diterima,Catatan',
      for (final po in rows)
        [
          po.id, po.outletId, po.supplierName, po.itemName, po.unit,
          po.quantity.toString(), po.receivedQuantity.toString(),
          po.remainingQuantity.toString(), po.unitCost.toString(),
          po.totalCost.toString(),
          (po.receivedQuantity * po.unitCost).toString(),
          po.status, po.createdAt, po.receivedAt ?? '', po.note,
        ].map(_csvCell).join(','),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\\r\\n')));
    _message('CSV ${rows.length} PO disalin. Tempel ke file .csv.');
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dateRange,
    );
    if (picked != null && mounted) {
      setState(() => dateRange = picked);
    }
  }

  Widget _metric(String label, String value) => Container(
    constraints: const BoxConstraints(minWidth: 155),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.blueGrey)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16)),
    ]),
  );

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Gagal memuat data pembelian lokal.'));
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final all = orders.forOutlet(outlet.selectedOutletId);
      final visible = all.where((po) {
        final query = search.trim().toLowerCase();
        final date = DateTime.tryParse(po.createdAt);
        return (filter == 'all' || po.status == filter) &&
            (supplierFilter == 'all' || po.supplierId == supplierFilter) &&
            (query.isEmpty || [
              po.id, po.supplierName, po.itemName, po.note,
            ].any((value) => value.toLowerCase().contains(query))) &&
            (dateRange == null || (date != null &&
                !DateUtils.dateOnly(date).isBefore(dateRange!.start) &&
                !DateUtils.dateOnly(date).isAfter(dateRange!.end)));
      }).toList();
      final supplierIds = all.map((po) => po.supplierId).toSet();
      final supplierNames = {
        for (final po in all) po.supplierId: po.supplierName,
      };
      final totalOrdered = all.fold<int>(0, (sum, po) => sum + po.totalCost);
      final totalReceived = all.fold<int>(0,
          (sum, po) => sum + po.receivedQuantity * po.unitCost);
      final outstanding = all.where((po) =>
          po.status == 'ordered' || po.status == 'partial').fold<int>(
          0, (sum, po) => sum + po.remainingQuantity * po.unitCost);
      final statusCounts = {
        for (final status in ['ordered', 'partial', 'received', 'cancelled'])
          status: all.where((po) => po.status == status).length,
      };
      final bySupplier = <String, List<FirefaPurchaseOrder>>{};
      for (final po in all) {
        bySupplier.putIfAbsent(po.supplierId, () => []).add(po);
      }
      final supplierSummary = bySupplier.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Icon(Icons.receipt_long_outlined, color: primary),
              const Text('Purchase Orders', style: TextStyle(
                fontSize: 21, fontWeight: FontWeight.bold)),
              FilledButton.icon(onPressed: allowed ? createOrder : null,
                icon: const Icon(Icons.add), label: const Text('Buat PO')),
            ]),
          const SizedBox(height: 8),
          Text('${outlet.selectedOutletName} • ${all.length} PO',
            style: const TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _metric('Total PO', '${all.length}'),
            _metric('Nilai Pesanan', 'Rp $totalOrdered'),
            _metric('Nilai Diterima', 'Rp $totalReceived'),
            _metric('Sisa Aktif', 'Rp $outstanding'),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in statusCounts.entries)
              Chip(label: Text('${entry.key}: ${entry.value}')),
          ]),
          const SizedBox(height: 12),
          const Text('Ringkasan Supplier',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final entry in supplierSummary)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${supplierNames[entry.key] ?? entry.key} • '
                '${entry.value.length} PO • '
                'Dipesan Rp ${entry.value.fold<int>(0, (sum, po) => sum + po.totalCost)} • '
                'Diterima Rp ${entry.value.fold<int>(0, (sum, po) => sum + po.receivedQuantity * po.unitCost)}',
              ),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, children: [
          DropdownButton<String>(value: supplierFilter,
            items: [
              const DropdownMenuItem(value: 'all',
                  child: Text('Semua supplier')),
              for (final id in supplierIds)
                DropdownMenuItem(value: id,
                  child: Text(supplierNames[id] ?? id)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => supplierFilter = value);
            },
          ),
          DropdownButton<String>(value: filter, items: const [
            DropdownMenuItem(value: 'all', child: Text('Semua status')),
            DropdownMenuItem(value: 'ordered', child: Text('Dipesan')),
            DropdownMenuItem(value: 'partial', child: Text('Diterima sebagian')),
            DropdownMenuItem(value: 'received', child: Text('Diterima')),
            DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
          ], onChanged: (value) {
            if (value != null) setState(() => filter = value);
          }),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 270, child: TextField(
              decoration: const InputDecoration(
                labelText: 'Cari PO, supplier, barang, catatan',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => search = value),
            )),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range),
              label: Text(dateRange == null ? 'Rentang tanggal' :
                '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} - '
                '${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}'),
            ),
            if (dateRange != null)
              TextButton(onPressed: () => setState(() => dateRange = null),
                child: const Text('Hapus tanggal')),
            OutlinedButton.icon(
              onPressed: allowed ? () => _copyCsv(visible) : null,
              icon: const Icon(Icons.copy),
              label: Text('Salin CSV (${visible.length} PO)'),
            ),
          ]),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(padding: EdgeInsets.all(24),
              child: Text('Belum ada purchase order.')),
          for (final po in visible)
            Card(child: Padding(padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${po.id} • ${po.supplierName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${po.itemName} • ${po.quantity} ${po.unit}'),
                  Text('Harga satuan Rp ${po.unitCost} • Total Rp ${po.totalCost}'),
                  Text('Status: ${po.status}'),
                  Text('Diterima: ${po.receivedQuantity} / ${po.quantity} ${po.unit} • Sisa: ${po.remainingQuantity}'),
                  for (final receipt in po.receipts)
                    Text('${receipt.id}: +${receipt.quantity} ${po.unit} • ${receipt.receivedAt}'),
                  Text('Dibuat: ${po.createdAt}'),
                  if (po.receivedAt != null)
                    Text('Diterima: ${po.receivedAt}'),
                  if (po.note.isNotEmpty) Text('Catatan: ${po.note}'),
                  if (allowed && (po.status == 'ordered' || po.status == 'partial'))
                    Wrap(spacing: 8, children: [
                      FilledButton(onPressed: () => decide(po, true),
                        child: const Text('Terima Barang')),
                      OutlinedButton(onPressed: () => decide(po, false),
                        child: const Text('Batalkan')),
                    ]),
                ]),
            )),
          const SizedBox(height: 12),
          const Text('Local Only • Mendukung penerimaan parsial • Tidak ada sinkronisasi cloud',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ]),
      );
    },
  );
}
