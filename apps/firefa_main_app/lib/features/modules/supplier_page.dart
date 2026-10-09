import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'supplier_store.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  static const primary = Color(0xFF008F83);
  final outlet = FirefaActiveOutletStore.instance;
  final store = FirefaSupplierStore.instance;
  late final Future<void> ready;
  String query = '';
  String status = 'all';

  bool get allowed =>
      FirefaAccess.can(outlet.role, FirefaPermission.inventoryManage) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

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

  Future<void> edit([FirefaSupplier? supplier]) async {
    if (!allowed || (supplier != null && supplier.outletId != outlet.selectedOutletId)) {
      return;
    }
    final sourceOutlet = outlet.selectedOutletId;
    final name = TextEditingController(text: supplier?.name ?? '');
    final contact = TextEditingController(text: supplier?.contact ?? '');
    final phone = TextEditingController(text: supplier?.phone ?? '');
    final address = TextEditingController(text: supplier?.address ?? '');
    final result = await showDialog<({String name, String contact, String phone, String address})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplier == null ? 'Tambah Supplier' : 'Edit Supplier'),
        content: SizedBox(width: 420, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nama supplier *')),
            TextField(controller: contact, maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nama kontak')),
            TextField(controller: phone, maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor telepon')),
            TextField(controller: address, maxLength: 250, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Alamat')),
          ]),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (
            name: name.text, contact: contact.text,
            phone: phone.text, address: address.text,
          )), child: const Text('Simpan')),
        ],
      ),
    );
    name.dispose();
    contact.dispose();
    phone.dispose();
    address.dispose();
    if (!mounted || result == null || !allowed ||
        sourceOutlet != outlet.selectedOutletId) {
      return;
    }
    final success = supplier == null
        ? store.add(outletId: sourceOutlet, name: result.name,
            contact: result.contact, phone: result.phone, address: result.address)
        : store.update(outletId: sourceOutlet, id: supplier.id, name: result.name,
            contact: result.contact, phone: result.phone, address: result.address);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Periksa nama supplier. Nama harus unik per outlet dan tidak kosong.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Gagal memuat supplier lokal.'));
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final all = store.forOutlet(outlet.selectedOutletId);
      final filtered = all.where((supplier) {
        if (!supplier.name.toLowerCase().contains(query.trim().toLowerCase()) &&
            !supplier.contact.toLowerCase().contains(query.trim().toLowerCase())) {
          return false;
        }
        if (status == 'active' && !supplier.isActive) return false;
        if (status == 'inactive' && supplier.isActive) return false;
        return true;
      }).toList();
      return LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 550;
        return SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Icon(Icons.local_shipping_outlined, color: primary),
                Text('Supplier Management', style: TextStyle(
                  fontSize: narrow ? 20 : 23, fontWeight: FontWeight.bold)),
                FilledButton.icon(
                  onPressed: allowed ? () => edit() : null,
                  icon: const Icon(Icons.add), label: const Text('Tambah Supplier')),
              ]),
            const SizedBox(height: 8),
            Text('${outlet.selectedOutletName} • ${all.length} supplier • ${all.where((s) => s.isActive).length} aktif',
              style: const TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 8, children: [
              SizedBox(width: narrow ? constraints.maxWidth - 32 : 280,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), labelText: 'Cari nama atau kontak'),
                  onChanged: (value) => setState(() => query = value),
                )),
              DropdownButton<String>(value: status, items: const [
                DropdownMenuItem(value: 'all', child: Text('Semua status')),
                DropdownMenuItem(value: 'active', child: Text('Aktif')),
                DropdownMenuItem(value: 'inactive', child: Text('Nonaktif')),
              ], onChanged: (value) {
                if (value != null) setState(() => status = value);
              }),
            ]),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const Padding(padding: EdgeInsets.all(24),
                child: Center(child: Text('Tidak ada supplier sesuai pencarian.'))),
            for (final supplier in filtered)
              Card(child: Padding(padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(supplier.name, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Kontak: ${supplier.contact.isEmpty ? "-" : supplier.contact}'),
                  Text('Telepon: ${supplier.phone.isEmpty ? "-" : supplier.phone}'),
                  Text('Alamat: ${supplier.address.isEmpty ? "-" : supplier.address}'),
                  Text(supplier.isActive ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(color: supplier.isActive ? primary : Colors.grey)),
                  if (allowed)
                    Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(onPressed: () => edit(supplier),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit')),
                        Switch(value: supplier.isActive, onChanged: (value) {
                          if (allowed && supplier.outletId == outlet.selectedOutletId) {
                            store.setActive(supplier.outletId, supplier.id, value);
                          }
                        }),
                      ]),
                ]),
              )),
            const SizedBox(height: 12),
            const Text('Data supplier lokal • Belum terhubung ke pembelian atau cloud',
              style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ]),
        ));
      });
    },
  );
}
