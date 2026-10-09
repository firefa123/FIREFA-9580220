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
  bool onlyPending = false;
  String reminderFilter = 'all';
  String workQueueFilter = 'due';
  String contactFilter = 'all';

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

  Future<void> _editFollowUp(FirefaPurchaseOrder po) async {
    if (!allowed || po.outletId != outlet.selectedOutletId ||
        (po.status != 'ordered' && po.status != 'partial')) {
      return;
    }
    final sourceOutlet = po.outletId;
    final controller = TextEditingController(text: po.followUpNote);
    DateTime? selected = po.followUpDate == null
        ? null : DateTime.tryParse(po.followUpDate!);
    final result = await showDialog<({String note, String? date})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Tindak lanjut ${po.id}'),
          content: SizedBox(width: 420, child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: controller,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Catatan tindak lanjut supplier'),
              ),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selected ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) update(() => selected = picked);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(selected == null ? 'Pilih tanggal pengingat'
                      : '${selected!.day}/${selected!.month}/${selected!.year}'),
                ),
                if (selected != null)
                  TextButton(onPressed: () => update(() => selected = null),
                      child: const Text('Hapus tanggal')),
              ]),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, (
              note: controller.text,
              date: selected == null ? null :
                  '${selected!.year.toString().padLeft(4, '0')}-'
                  '${selected!.month.toString().padLeft(2, '0')}-'
                  '${selected!.day.toString().padLeft(2, '0')}',
            )), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!mounted || result == null || !allowed ||
        outlet.selectedOutletId != sourceOutlet) {
      return;
    }
    if (!orders.setFollowUp(
      outletId: sourceOutlet, orderId: po.id,
      note: result.note, date: result.date,
    )) {
      _message('Gagal menyimpan tindak lanjut PO.');
    }
  }

  void _markContacted(FirefaPurchaseOrder po, bool contacted) {
    if (!allowed || po.outletId != outlet.selectedOutletId) return;
    final success = orders.setFollowUpContacted(
      outletId: po.outletId,
      orderId: po.id,
      contacted: contacted,
    );
    _message(success
        ? (contacted ? 'Kontak supplier dicatat.' : 'Status kontak direset.')
        : 'Gagal memperbarui status kontak supplier.');
  }

  String _csvCell(String value) {
    final safe = value.replaceAll('"', '""');
    final guarded = safe.isNotEmpty && '=+@-'.contains(safe[0]) ? "'$safe" : safe;
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
    await Clipboard.setData(ClipboardData(text: lines.join('\r\n')));
    _message('CSV ${rows.length} PO disalin. Tempel ke file .csv.');
  }

  Future<void> _copyFollowUpReport(List<FirefaPurchaseOrder> rows,
      String Function(FirefaPurchaseOrder) reminderStatus) async {
    final selectedOutlet = outlet.selectedOutletId;
    if (!allowed || rows.any((po) => po.outletId != selectedOutlet)) {
      return;
    }
    final active = rows.where((po) =>
        po.status == 'ordered' || po.status == 'partial').toList()
      ..sort((a, b) {
        final first = a.followUpDate ?? '9999-12-31';
        final second = b.followUpDate ?? '9999-12-31';
        final byDate = first.compareTo(second);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    final lines = <String>[
      'PO ID,Outlet ID,Supplier,Barang,Status PO,Tanggal PO,Tanggal Pengingat,Status Pengingat,Catatan Tindak Lanjut,Status Kontak,Waktu Dihubungi,Sisa Qty,Satuan,Nilai Sisa',
      for (final po in active)
        [
          po.id, po.outletId, po.supplierName, po.itemName,
          po.status, po.createdAt, po.followUpDate ?? '',
          reminderStatus(po), po.followUpNote,
          po.followUpContactedAt == null ? 'Belum dihubungi' : 'Sudah dihubungi',
          po.followUpContactedAt ?? '',
          po.remainingQuantity.toString(), po.unit,
          (po.remainingQuantity * po.unitCost).toString(),
        ].map(_csvCell).join(','),
    ];
    if (!mounted || !allowed || outlet.selectedOutletId != selectedOutlet) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\r\n')));
    _message('Laporan tindak lanjut ${active.length} PO aktif disalin sebagai CSV.');
  }

  String _receiptAuditStatus(FirefaPurchaseOrder po) {
    if (po.receipts.isEmpty && po.receivedQuantity > 0) {
      return 'legacy_no_details';
    }
    final receiptTotal = po.receipts.fold<int>(
        0, (sum, receipt) => sum + receipt.quantity);
    if (receiptTotal != po.receivedQuantity ||
        po.receivedQuantity < 0 || po.receivedQuantity > po.quantity ||
        po.receipts.any((receipt) => receipt.quantity <= 0)) {
      return 'mismatch';
    }
    return 'matched';
  }

  Future<void> _copyReceiptAudit(List<FirefaPurchaseOrder> rows) async {
    if (!allowed || rows.any((po) => po.outletId != outlet.selectedOutletId)) {
      return;
    }
    final lines = <String>[
      'PO ID,Outlet ID,Supplier,Barang,Status PO,Receipt ID,Tanggal Receipt,Qty Receipt,Qty Diterima PO,Total Qty Receipt,Selisih,Status Audit',
      for (final po in rows)
        for (final receipt in po.receipts.isEmpty
            ? <FirefaPurchaseReceipt?>[null]
            : <FirefaPurchaseReceipt?>[...po.receipts])
          [
            po.id, po.outletId, po.supplierName, po.itemName, po.status,
            receipt?.id ?? '', receipt?.receivedAt ?? '',
            receipt?.quantity.toString() ?? '',
            po.receivedQuantity.toString(),
            po.receipts.fold<int>(0, (n, r) => n + r.quantity).toString(),
            (po.receivedQuantity -
                po.receipts.fold<int>(0, (n, r) => n + r.quantity)).toString(),
            _receiptAuditStatus(po),
          ].map(_csvCell).join(','),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\r\n')));
    _message('Audit receipt ${rows.length} PO disalin sebagai CSV.');
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

  Future<void> _showOrderDetail(FirefaPurchaseOrder po) async {
    if (!outlet.canAccessOutlet(po.outletId) ||
        po.outletId != outlet.selectedOutletId) {
      return;
    }
    final receivedValue = po.receivedQuantity * po.unitCost;
    final remainingValue = po.remainingQuantity * po.unitCost;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detail PO ${po.id}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Supplier: ${po.supplierName}'),
                Text('Barang: ${po.itemName}'),
                Text('Outlet: ${po.outletId}'),
                Text('Status: ${po.status}'),
                Text('Dibuat: ${po.createdAt}'),
                const Divider(),
                Text('Jumlah dipesan: ${po.quantity} ${po.unit}'),
                Text('Jumlah diterima: ${po.receivedQuantity} ${po.unit}'),
                Text('Sisa: ${po.remainingQuantity} ${po.unit}'),
                Text('Harga satuan: Rp ${po.unitCost}'),
                Text('Nilai PO: Rp ${po.totalCost}'),
                Text('Nilai diterima: Rp $receivedValue'),
                Text('Nilai sisa: Rp $remainingValue'),
                if (po.note.isNotEmpty) Text('Catatan: ${po.note}'),
                if (po.followUpNote.isNotEmpty)
                  Text('Tindak lanjut: ${po.followUpNote}'),
                if (po.followUpDate != null)
                  Text('Tanggal pengingat: ${po.followUpDate}'),
                const SizedBox(height: 12),
                Text('Rekonsiliasi receipt: ${_receiptAuditStatus(po)}'),
                Text('Total rincian receipt: ${po.receipts.fold<int>(0, (n, r) => n + r.quantity)} ${po.unit}'),
                Text('Selisih: ${po.receivedQuantity - po.receipts.fold<int>(0, (n, r) => n + r.quantity)} ${po.unit}'),
                const SizedBox(height: 12),
                const Text('Timeline PO',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('PO dibuat'),
                  subtitle: Text(po.createdAt),
                ),
                for (final receipt in po.receipts)
                  ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text('Barang diterima: +${receipt.quantity} ${po.unit}'),
                    subtitle: Text('${receipt.receivedAt} • ${receipt.id}'),
                  ),
                if (po.status == 'received' && po.receipts.isEmpty)
                  ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Diterima penuh (data lama)'),
                    subtitle: Text(po.receivedAt ?? 'Waktu tidak tersedia'),
                  ),
                if (po.status == 'cancelled')
                  ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cancel_outlined),
                    title: const Text('Sisa PO dibatalkan'),
                    subtitle: Text(po.cancelledAt ??
                        'Waktu pembatalan tidak tercatat (data lama)'),
                  ),
                if (po.status == 'ordered' || po.status == 'partial')
                  ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pending_outlined),
                    title: Text('Menunggu ${po.remainingQuantity} ${po.unit}'),
                    subtitle: const Text('Sisa pesanan masih aktif'),
                  ),
                const Divider(),
                const Text('Riwayat penerimaan',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (po.receipts.isEmpty)
                  const Text('Belum ada penerimaan tercatat.'),
                for (final receipt in po.receipts)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${receipt.id} • +${receipt.quantity} ${po.unit}'),
                    subtitle: Text(receipt.receivedAt),
                    trailing: Text('Rp ${receipt.quantity * po.unitCost}'),
                  ),
                if (po.status == 'received' && po.receipts.isEmpty)
                  const Text(
                    'PO lama: total penerimaan tercatat, tetapi rincian '
                    'penerimaan historis tidak tersedia.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                if (po.status == 'cancelled' && po.remainingQuantity > 0)
                  const Text('Sisa pesanan dibatalkan; tidak menambah stok.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup')),
        ],
      ),
    );
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
      final supplierIds = all.map((po) => po.supplierId).toSet();
      final effectiveSupplier = supplierIds.contains(supplierFilter)
          ? supplierFilter : 'all';
      final today = DateUtils.dateOnly(DateTime.now());
      String reminderStatus(FirefaPurchaseOrder po) {
        if (po.status != 'ordered' && po.status != 'partial') {
          return 'inactive';
        }
        final due = po.followUpDate == null
            ? null : DateTime.tryParse(po.followUpDate!);
        if (due == null) return 'unscheduled';
        final day = DateUtils.dateOnly(due);
        if (day.isBefore(today)) return 'overdue';
        if (day.isAtSameMomentAs(today)) return 'today';
        return 'upcoming';
      }
      final activeReminders = all.where((po) =>
          po.status == 'ordered' || po.status == 'partial').toList();
      final overdueReminders = activeReminders.where((po) =>
          reminderStatus(po) == 'overdue').length;
      final todayReminders = activeReminders.where((po) =>
          reminderStatus(po) == 'today').length;
      final upcomingReminders = activeReminders.where((po) =>
          reminderStatus(po) == 'upcoming').length;
      final unscheduledReminders = activeReminders.where((po) =>
          reminderStatus(po) == 'unscheduled').length;
      final reminderPriority = activeReminders.where((po) =>
          reminderStatus(po) == 'overdue' ||
          reminderStatus(po) == 'today').toList()
        ..sort((a, b) {
          final byDate = (a.followUpDate ?? '').compareTo(b.followUpDate ?? '');
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      final contactedCount = activeReminders.where((po) =>
          po.followUpContactedAt != null).length;
      final uncontactedCount = activeReminders.length - contactedCount;
      final dueUncontactedCount = activeReminders.where((po) =>
          po.followUpContactedAt == null &&
          (reminderStatus(po) == 'overdue' ||
              reminderStatus(po) == 'today')).length;
      final workQueue = activeReminders.where((po) {
        if (contactFilter == 'contacted' && po.followUpContactedAt == null) {
          return false;
        }
        if (contactFilter == 'uncontacted' && po.followUpContactedAt != null) {
          return false;
        }
        final status = reminderStatus(po);
        if (workQueueFilter == 'due') {
          return status == 'overdue' || status == 'today';
        }
        return workQueueFilter == 'all' || status == workQueueFilter;
      }).toList()
        ..sort((a, b) {
          int priority(FirefaPurchaseOrder po) {
            switch (reminderStatus(po)) {
              case 'overdue': return 0;
              case 'today': return 1;
              case 'upcoming': return 2;
              default: return 3;
            }
          }
          final byPriority = priority(a).compareTo(priority(b));
          if (byPriority != 0) return byPriority;
          final byDate = (a.followUpDate ?? '9999-12-31')
              .compareTo(b.followUpDate ?? '9999-12-31');
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      final visible = all.where((po) {
        final query = search.trim().toLowerCase();
        final date = DateTime.tryParse(po.createdAt);
        return (filter == 'all' || po.status == filter) &&
            (effectiveSupplier == 'all' || po.supplierId == effectiveSupplier) &&
            (!onlyPending || po.status == 'ordered' || po.status == 'partial') &&
            (reminderFilter == 'all' || reminderStatus(po) == reminderFilter) &&
            (query.isEmpty || [
              po.id, po.supplierName, po.itemName, po.note,
            ].any((value) => value.toLowerCase().contains(query))) &&
            (dateRange == null || (date != null &&
                !DateUtils.dateOnly(date).isBefore(dateRange!.start) &&
                !DateUtils.dateOnly(date).isAfter(dateRange!.end)));
      }).toList();
      final supplierNames = {
        for (final po in all) po.supplierId: po.supplierName,
      };
      final totalOrdered = all.fold<int>(0, (sum, po) => sum + po.totalCost);
      final totalReceived = all.fold<int>(0,
          (sum, po) => sum + po.receivedQuantity * po.unitCost);
      final outstanding = all.where((po) =>
          po.status == 'ordered' || po.status == 'partial').fold<int>(
          0, (sum, po) => sum + po.remainingQuantity * po.unitCost);
      final pending = all.where((po) =>
          po.status == 'ordered' || po.status == 'partial').toList();
      final now = DateTime.now();
      int ageDays(FirefaPurchaseOrder po) {
        final created = DateTime.tryParse(po.createdAt);
        if (created == null) return 0;
        final days = DateUtils.dateOnly(now).difference(
            DateUtils.dateOnly(created)).inDays;
        return days < 0 ? 0 : days;
      }
      final pendingOver7 = pending.where((po) => ageDays(po) >= 7).length;
      final pendingOver30 = pending.where((po) => ageDays(po) >= 30).length;
      final oldestPending = pending.isEmpty ? 0 :
          pending.map(ageDays).reduce((a, b) => a > b ? a : b);
      final followUp = [...pending]..sort((a, b) {
        final age = ageDays(b).compareTo(ageDays(a));
        return age != 0 ? age : a.id.compareTo(b.id);
      });
      final auditMismatch = all.where(
          (po) => _receiptAuditStatus(po) == 'mismatch').length;
      final auditLegacy = all.where(
          (po) => _receiptAuditStatus(po) == 'legacy_no_details').length;
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
          const Text('Rekonsiliasi Penerimaan',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _metric('Selisih Receipt', '$auditMismatch'),
            _metric('PO Lama Tanpa Detail', '$auditLegacy'),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: allowed ? () => _copyReceiptAudit(visible) : null,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text('Salin CSV Audit (${visible.length} PO)'),
          ),
          const SizedBox(height: 12),
          const Text('Dashboard Pengingat Tindak Lanjut',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _metric('Terlambat', '$overdueReminders'),
            _metric('Hari Ini', '$todayReminders'),
            _metric('Mendatang', '$upcomingReminders'),
            _metric('Belum Dijadwalkan', '$unscheduledReminders'),
          ]),
          if (reminderPriority.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Prioritas pengingat (tanggal terlama lebih dulu)',
                style: TextStyle(color: Colors.blueGrey)),
            for (final po in reminderPriority.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Wrap(spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${po.followUpDate} • ${po.id} • ${po.supplierName}'
                        ' • ${reminderStatus(po) == 'overdue' ? 'Terlambat' : 'Hari ini'}'),
                    if (allowed)
                      TextButton(
                        onPressed: () => _editFollowUp(po),
                        child: const Text('Tindak lanjuti'),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: allowed
                ? () => _copyFollowUpReport(visible, reminderStatus)
                : null,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text('Salin CSV Tindak Lanjut (${visible.where((po) => po.status == 'ordered' || po.status == 'partial').length} PO)'),
          ),
          const SizedBox(height: 12),
          const Text('Monitoring Kontak Supplier',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _metric('Sudah Dihubungi', '$contactedCount'),
            _metric('Belum Dihubungi', '$uncontactedCount'),
            _metric('Perlu Kontak Segera', '$dueUncontactedCount'),
          ]),
          const SizedBox(height: 12),
          const Text('Antrean Kerja Follow-up Supplier',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<String>(
              value: workQueueFilter,
              items: const [
                DropdownMenuItem(value: 'due', child: Text('Perlu tindakan')),
                DropdownMenuItem(value: 'overdue', child: Text('Terlambat')),
                DropdownMenuItem(value: 'today', child: Text('Hari ini')),
                DropdownMenuItem(value: 'upcoming', child: Text('Mendatang')),
                DropdownMenuItem(value: 'unscheduled', child: Text('Belum dijadwalkan')),
                DropdownMenuItem(value: 'all', child: Text('Semua PO aktif')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => workQueueFilter = value);
                }
              },
            ),
            DropdownButton<String>(
              value: contactFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Semua status kontak')),
                DropdownMenuItem(value: 'contacted', child: Text('Sudah dihubungi')),
                DropdownMenuItem(value: 'uncontacted', child: Text('Belum dihubungi')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => contactFilter = value);
              },
            ),
            Text('${workQueue.length} PO dalam antrean'),
            if (workQueue.length > 30)
              const Text('Menampilkan 30 teratas; gunakan filter untuk mempersempit.'),
          ]),
          if (workQueue.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Tidak ada PO pada kategori antrean ini.'),
            ),
          for (final po in workQueue.take(30))
            Card(
              child: ListTile(
                isThreeLine: true,
                title: Text('${po.id} • ${po.supplierName}'),
                subtitle: Text('${po.itemName} • sisa ${po.remainingQuantity} ${po.unit}'
                    '\\nPengingat: ${po.followUpDate ?? 'Belum dijadwalkan'}'
                    ' • ${reminderStatus(po)}'
                    '\\n${po.followUpNote.isEmpty ? 'Belum ada catatan' : po.followUpNote}'
                    '\\n${po.followUpContactedAt == null ? 'Belum dihubungi' : 'Dihubungi: ${po.followUpContactedAt}'}'),
                trailing: allowed
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: po.followUpContactedAt == null
                              ? 'Tandai supplier sudah dihubungi'
                              : 'Reset status dihubungi',
                          icon: Icon(po.followUpContactedAt == null
                              ? Icons.check_circle_outline
                              : Icons.check_circle),
                          onPressed: () => _markContacted(
                              po, po.followUpContactedAt == null),
                        ),
                        IconButton(
                          tooltip: 'Perbarui tindak lanjut',
                          icon: const Icon(Icons.edit_calendar_outlined),
                          onPressed: () => _editFollowUp(po),
                        ),
                      ])
                    : null,
                onTap: () => _showOrderDetail(po),
              ),
            ),
          const SizedBox(height: 12),
          const Text('Monitoring PO Aktif',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _metric('PO Menunggu', '${pending.length}'),
            _metric('Umur ≥7 Hari', '$pendingOver7'),
            _metric('Umur ≥30 Hari', '$pendingOver30'),
            _metric('Tertua', '$oldestPending hari'),
          ]),
          if (followUp.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Prioritas tindak lanjut (PO tertua lebih dulu)',
                style: TextStyle(color: Colors.blueGrey)),
            for (final po in followUp.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('${po.id} • ${po.supplierName} • '
                    '${ageDays(po)} hari • sisa ${po.remainingQuantity} '
                    '${po.unit} • Rp ${po.remainingQuantity * po.unitCost}'),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in statusCounts.entries)
              Chip(label: Text('${entry.key}: ${entry.value}')),
          ]),
          const SizedBox(height: 12),
          const Text('Ringkasan Supplier',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final entry in supplierSummary)
            Builder(builder: (context) {
              final rows = entry.value;
              final ordered = rows.fold<int>(0, (n, po) => n + po.totalCost);
              final received = rows.fold<int>(0,
                  (n, po) => n + po.receivedQuantity * po.unitCost);
              final active = rows.where((po) =>
                  po.status == 'ordered' || po.status == 'partial').toList();
              final outstanding = active.fold<int>(0,
                  (n, po) => n + po.remainingQuantity * po.unitCost);
              final completed = rows.where((po) =>
                  po.status == 'received').length;
              final cancelled = rows.where((po) =>
                  po.status == 'cancelled').length;
              final ratio = ordered == 0 ? 0.0 : received / ordered;
              return Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplierNames[entry.key] ?? entry.key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _metric('Total PO', '${rows.length}'),
                      _metric('PO Aktif', '${active.length}'),
                      _metric('Selesai', '$completed'),
                      _metric('Dibatalkan', '$cancelled'),
                      _metric('Dipesan', 'Rp $ordered'),
                      _metric('Diterima', 'Rp $received'),
                      _metric('Outstanding', 'Rp $outstanding'),
                      _metric('Rasio Penerimaan',
                          '${(ratio * 100).toStringAsFixed(1)}%'),
                    ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
                    TextButton.icon(
                      onPressed: () => setState(() => supplierFilter = entry.key),
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: const Text('Filter PO supplier ini'),
                    ),
                  ],
                ),
              ));
            }),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, children: [
          DropdownButton<String>(value: effectiveSupplier,
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
          DropdownButton<String>(
            value: reminderFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Semua pengingat')),
              DropdownMenuItem(value: 'overdue', child: Text('Pengingat terlambat')),
              DropdownMenuItem(value: 'today', child: Text('Pengingat hari ini')),
              DropdownMenuItem(value: 'upcoming', child: Text('Pengingat mendatang')),
              DropdownMenuItem(value: 'unscheduled', child: Text('Belum dijadwalkan')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => reminderFilter = value);
              }
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Tampilkan hanya PO yang masih aktif'),
            value: onlyPending,
            onChanged: (value) => setState(() => onlyPending = value ?? false),
          ),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showOrderDetail(po),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Detail & Audit'),
                    ),
                  ),
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
                  if (po.followUpNote.isNotEmpty)
                    Text('Tindak lanjut: ${po.followUpNote}'),
                  if (po.followUpDate != null)
                    Text('Pengingat: ${po.followUpDate}'),
                  if (allowed && (po.status == 'ordered' || po.status == 'partial'))
                    TextButton.icon(
                      onPressed: () => _editFollowUp(po),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Atur Tindak Lanjut'),
                    ),
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
