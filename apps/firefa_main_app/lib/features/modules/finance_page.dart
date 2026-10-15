import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'finance_store.dart';
import 'inventory_store.dart';
import 'purchase_order_store.dart';
import 'supplier_store.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with SingleTickerProviderStateMixin {
  static const primary = Color(0xFF008F83);
  final finance = FirefaFinanceStore.instance;
  final outlet = FirefaActiveOutletStore.instance;
  late final TabController tabs;
  late final Future<void> ready;
  String get outletId => outlet.selectedOutletId;
  bool get allowed => FirefaAccess.can(outlet.role, FirefaPermission.inventoryManage) && outlet.canAccessOutlet(outletId);

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    ready = _initialize();
    finance.addListener(_refresh);
    outlet.addListener(_refresh);
  }
  Future<void> _initialize() async {
    await Future.wait([finance.initialize(), FirefaSupplierStore.instance.initialize(), FirefaInventoryStore.instance.initialize(), FirefaPurchaseOrderStore.instance.initialize()]);
    await finance.syncPurchaseReceipts(outletId);
  }
  void _refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() { finance.removeListener(_refresh); outlet.removeListener(_refresh); tabs.dispose(); super.dispose(); }

  String money(int n) => 'Rp ${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  void message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<String?> _textDialog(String title, String label, {String initial = '', TextInputType type = TextInputType.text, bool requiredField = true}) async {
    final c = TextEditingController(text: initial);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: TextField(controller: c, autofocus: true, keyboardType: type,
        inputFormatters: type == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : [],
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () { if (requiredField && c.text.trim().isEmpty) return; Navigator.pop(ctx, c.text.trim()); }, child: const Text('Simpan'))]));
    c.dispose(); return result;
  }
  Future<void> _addExpense() async {
    final category = await _textDialog('Pengeluaran baru', 'Kategori (sewa, listrik, dll.)');
    if (category == null) return;
    final amountText = await _textDialog('Nominal pengeluaran', 'Nominal rupiah', type: TextInputType.number);
    final amount = int.tryParse(amountText ?? '');
    if (amount == null || amount <= 0) { if (amountText != null) message('Nominal tidak valid.'); return; }
    final note = await _textDialog('Keterangan', 'Catatan (opsional)', requiredField: false);
    if (note == null) return;
    final method = await _methodDialog();
    if (method == null) return;
    if (finance.addExpense(outletId: outletId, category: category, amount: amount, method: method, note: note)) message('Pengeluaran tersimpan.');
    else message('Pengeluaran gagal disimpan.');
  }
  Future<String?> _methodDialog() => showDialog<String>(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Metode pembayaran'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final m in ['Cash', 'Transfer', 'QRIS', 'Bank']) ListTile(title: Text(m), onTap: () => Navigator.pop(ctx, m))])));
  Future<void> _pay(FirefaSupplierPayable p) async {
    final raw = await _textDialog('Bayar utang pemasok', 'Nominal (maks. ${money(p.outstanding)})', type: TextInputType.number);
    if (raw == null) return;
    final amount = int.tryParse(raw);
    if (amount == null || amount <= 0 || amount > p.outstanding) { message('Nominal pembayaran tidak valid.'); return; }
    final method = await _methodDialog(); if (method == null) return;
    final note = await _textDialog('Catatan pembayaran', 'Referensi transfer (opsional)', requiredField: false);
    if (note == null) return;
    if (finance.recordPayablePayment(outletId: outletId, payableId: p.id, amount: amount, method: method, note: note)) {
      await finance.waitForPendingSave(); if (mounted) message('Pembayaran utang dicatat.');
    } else { message('Pembayaran gagal dicatat.'); }
  }
  Future<void> _newConsignment() async {
    final suppliers = FirefaSupplierStore.instance.forOutlet(outletId).where((s) => s.isActive).toList();
    final items = FirefaInventoryStore.instance.forOutlet(outletId);
    if (suppliers.isEmpty || items.isEmpty) { message('Tambahkan supplier dan barang inventory terlebih dahulu.'); return; }
    String supplierId = suppliers.first.id, itemId = items.first.id;
    final qty = TextEditingController(), cost = TextEditingController();
    final result = await showDialog<({String supplier, String item, int qty, int cost})>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('Terima barang konsinyasi'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: supplierId, isExpanded: true, decoration: const InputDecoration(labelText: 'Supplier'),
          items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(), onChanged: (v) { if (v != null) setLocal(() => supplierId = v); }),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: itemId, isExpanded: true, decoration: const InputDecoration(labelText: 'Barang inventory'),
          items: items.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (${i.unit})'))).toList(), onChanged: (v) { if (v != null) setLocal(() => itemId = v); }),
        const SizedBox(height: 12),
        TextField(controller: qty, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Jumlah diterima')),
        TextField(controller: cost, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Harga pokok per unit (Rp)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () { final q = int.tryParse(qty.text), c = int.tryParse(cost.text); if (q != null && q > 0 && c != null && c >= 0) Navigator.pop(ctx, (supplier:supplierId,item:itemId,qty:q,cost:c)); }, child: const Text('Terima'))])));
    qty.dispose(); cost.dispose();
    if (result == null) return;
    final ok = await finance.receiveConsignment(outletId: outletId, supplierId: result.supplier, itemId: result.item, quantity: result.qty, unitCost: result.cost);
    if (mounted) message(ok ? 'Konsinyasi diterima dan stok bertambah.' : 'Penerimaan konsinyasi gagal.');
  }
  Future<void> _consignmentAction(FirefaConsignmentBatch batch, String action) async {
    final raw = await _textDialog(action, action == 'Setor ke supplier' ? 'Nominal pembayaran (Rp)' : 'Jumlah unit', type: TextInputType.number);
    if (raw == null) return; final value = int.tryParse(raw);
    if (value == null || value <= 0) { message('Masukkan angka lebih dari nol.'); return; }
    bool ok;
    if (action == 'Catat terjual') ok = finance.recordConsignmentSale(outletId: outletId, batchId: batch.id, quantity: value);
    else if (action == 'Retur ke supplier') ok = await finance.returnConsignment(outletId: outletId, batchId: batch.id, quantity: value);
    else ok = finance.settleConsignment(outletId: outletId, batchId: batch.id, amount: value);
    if (mounted) message(ok ? '$action berhasil dicatat.' : 'Gagal: cek jumlah stok, sisa barang, atau saldo kewajiban.');
  }
  Widget _metric(String label, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Icon(icon, color: primary, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))])));
  Widget _empty(String text) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center)));
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(future: ready, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Gagal memuat keuangan: ${snapshot.error}'));
      if (!allowed) return _empty('Akses keuangan tidak tersedia untuk peran ini atau outlet aktif.');
      final payables = finance.payablesForOutlet(outletId), expenses = finance.expensesForOutlet(outletId), consignments = finance.consignmentsForOutlet(outletId);
      final outstanding = finance.outstandingPayables(outletId), expenseTotal = finance.totalExpenses(outletId), consignmentDue = finance.consignmentDue(outletId);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Pembelian & Keuangan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6), const Text('Utang pemasok, konsinyasi, pengeluaran, dan ringkasan keuangan outlet.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(width: 230, child: _metric('Utang pemasok', money(outstanding), Icons.account_balance_wallet_outlined)),
          SizedBox(width: 230, child: _metric('Pengeluaran tercatat', money(expenseTotal), Icons.payments_outlined)),
          SizedBox(width: 230, child: _metric('Kewajiban konsinyasi', money(consignmentDue), Icons.inventory_2_outlined)),
        ]),
        const SizedBox(height: 12),
        TabBar(controller: tabs, isScrollable: true, labelColor: primary, tabs: const [
          Tab(text: 'Utang Pemasok'), Tab(text: 'Konsinyasi'), Tab(text: 'Pengeluaran'), Tab(text: 'Laporan')]),
        Expanded(child: TabBarView(controller: tabs, children: [
          Column(children: [
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async {
              try { final n = await finance.syncPurchaseReceipts(outletId); if (mounted) message(n == 0 ? 'Utang sudah tersinkron.' : '$n tagihan baru dibuat dari penerimaan PO.'); }
              catch (_) { message('Sinkronisasi penerimaan PO gagal.'); }
            }, icon: const Icon(Icons.sync), label: const Text('Sinkronkan penerimaan PO'))),
            Expanded(child: payables.isEmpty ? _empty('Belum ada utang. Buat PO dan terima barang untuk membentuk tagihan pemasok.') :
              ListView.builder(itemCount: payables.length, itemBuilder: (ctx, i) {
                final p = payables[i];
                return Card(child: ListTile(isThreeLine: true, title: Text('${p.supplierName} • ${p.itemName}'),
                  subtitle: Text('${p.purchaseOrderId} / ${p.receiptId} • ${p.quantity} ${p.unit}\nTotal ${money(p.amount)} • Dibayar ${money(p.paidAmount)}\nSisa ${money(p.outstanding)} • ${p.status}'),
                  trailing: p.outstanding > 0 ? IconButton(tooltip: 'Bayar', icon: const Icon(Icons.payments), onPressed: () => _pay(p)) : const Icon(Icons.check_circle, color: primary)));
              })),
          ]),
          Column(children: [
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _newConsignment, icon: const Icon(Icons.add), label: const Text('Terima konsinyasi'))),
            Expanded(child: consignments.isEmpty ? _empty('Belum ada barang konsinyasi.') : ListView.builder(itemCount: consignments.length, itemBuilder: (ctx, i) {
              final c = consignments[i];
              return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.itemName} • ${c.supplierName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Diterima ${c.receivedQuantity} • Terjual ${c.soldQuantity} • Retur ${c.returnedQuantity} • Sisa ${c.remainingQuantity}'),
                Text('Harga pokok ${money(c.unitCost)}/unit • Kewajiban belum setor ${money(c.amountDue)}'),
                Wrap(children: [
                  TextButton(onPressed: c.remainingQuantity > 0 ? () => _consignmentAction(c, 'Catat terjual') : null, child: const Text('Catat terjual')),
                  TextButton(onPressed: c.remainingQuantity > 0 ? () => _consignmentAction(c, 'Retur ke supplier') : null, child: const Text('Retur')),
                  TextButton(onPressed: c.amountDue > 0 ? () => _consignmentAction(c, 'Setor ke supplier') : null, child: const Text('Setor')),
                ])
              ])));
            })),
          ]),
          Column(children: [
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _addExpense, icon: const Icon(Icons.add), label: const Text('Catat pengeluaran'))),
            Expanded(child: expenses.isEmpty ? _empty('Belum ada pengeluaran tercatat.') : ListView.builder(itemCount: expenses.length, itemBuilder: (ctx, i) {
              final e = expenses[i]; return Card(child: ListTile(title: Text(e.category), subtitle: Text('${e.method} • ${e.note}\n${DateTime.parse(e.createdAt).toLocal()}'), trailing: Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.bold))));
            })),
          ]),
          ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
            _metric('Total utang terbuka', money(outstanding), Icons.account_balance_wallet),
            _metric('Total pengeluaran tersimpan', money(expenseTotal), Icons.money_off),
            _metric('Utang konsinyasi', money(consignmentDue), Icons.inventory_2),
            _metric('Jumlah tagihan pemasok', '${payables.length}', Icons.receipt_long),
            _metric('Jumlah transaksi pengeluaran', '${expenses.length}', Icons.list_alt),
            _metric('Batch konsinyasi aktif/riwayat', '${consignments.length}', Icons.inventory),
            const Padding(padding: EdgeInsets.all(12), child: Text('Laporan ini merupakan ringkasan lokal per outlet. Nilai pengeluaran dihitung dari seluruh catatan tersimpan; belum merupakan laporan laba rugi akuntansi penuh.')),
            FilledButton.icon(onPressed: () {
              final rows = <String>['Jenis,Referensi,Nama,Total,Dibayar,Sisa,Status'];
              for (final p in payables) { rows.add('Utang,${p.purchaseOrderId},${p.supplierName} - ${p.itemName},${p.amount},${p.paidAmount},${p.outstanding},${p.status}'); }
              for (final e in expenses) { rows.add('Pengeluaran,${e.id},${e.category},${e.amount},0,${e.amount},${e.method}'); }
              for (final c in consignments) { rows.add('Konsinyasi,${c.id},${c.supplierName} - ${c.itemName},${c.soldQuantity*c.unitCost},${c.settledAmount},${c.amountDue},${c.remainingQuantity} sisa'); }
              Clipboard.setData(ClipboardData(text: rows.join('\n'))); message('Laporan CSV disalin ke clipboard.');
            }, icon: const Icon(Icons.copy), label: const Text('Salin laporan CSV')),
          ]),
        ])),
      ]);
    });
  }
}
