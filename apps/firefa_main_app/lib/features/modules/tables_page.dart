import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'table_store.dart';

class TablesPage extends StatefulWidget {
  const TablesPage({super.key});
  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  static const primary = Color(0xFF008F83);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  final outlet = FirefaActiveOutletStore.instance;
  final store = FirefaTableStore.instance;
  late final Future<void> ready;

  @override
  void initState() {
    super.initState();
    ready = store.initialize();
    outlet.addListener(refresh);
    store.addListener(refresh);
  }

  void refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    outlet.removeListener(refresh);
    store.removeListener(refresh);
    super.dispose();
  }

  bool get allowed => FirefaAccess.can(outlet.role, FirefaPermission.tablesManage) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

  Future<void> addTable() async {
    if (!allowed) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Meja'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Nama meja', hintText: 'Contoh: Meja 01'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Simpan')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null) return;
    if (!allowed || !store.add(outlet.selectedOutletId, name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama meja kosong atau sudah digunakan di outlet ini.')));
    }
  }

  Future<void> editTable(FirefaTable table) async {
    if (!allowed || table.outletId != outlet.selectedOutletId) return;
    final originalOutletId = table.outletId;
    final controller = TextEditingController(text: table.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Nama Meja'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Nama meja'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Simpan')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null) return;
    if (!allowed || outlet.selectedOutletId != originalOutletId) return;
    if (!store.rename(originalOutletId, table.id, name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nama meja tidak valid atau sudah digunakan di outlet ini.'),
      ));
    }
  }

  Future<void> deleteTable(FirefaTable table) async {
    if (!allowed || table.outletId != outlet.selectedOutletId) return;
    final originalOutletId = table.outletId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Meja?'),
        content: Text('Meja "${table.name}" akan dihapus dari outlet ini. '
            'Tindakan ini tidak dapat dibatalkan. Data pesanan tidak diubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus Meja'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (!allowed || outlet.selectedOutletId != originalOutletId) return;
    if (!store.remove(originalOutletId, table.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Meja tidak ditemukan atau tidak dapat dihapus.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Gagal memuat meja lokal. Data lama tidak diubah.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final tables = store.forOutlet(outlet.selectedOutletId);
        final available = tables.where((t) => !t.occupied).length;
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 540;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.table_restaurant, color: primary),
                    const Text('Tables Management',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: ink)),
                    FilledButton.icon(
                      onPressed: allowed ? addTable : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Meja'),
                      style: FilledButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${outlet.selectedOutletName} • ${tables.length} meja • $available tersedia',
                    style: const TextStyle(color: muted)),
                const SizedBox(height: 8),
                const Text('Data lokal • Status meja diatur manual • Belum terhubung otomatis ke POS/cloud',
                    style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 18),
                if (tables.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(children: [
                      Icon(Icons.table_restaurant_outlined, size: 40, color: muted),
                      SizedBox(height: 12),
                      Text('Belum ada meja di outlet ini', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text('Gunakan Tambah Meja untuk membuat data lokal.', textAlign: TextAlign.center),
                    ]),
                  ),
                if (tables.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tables.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 950 ? 4 : constraints.maxWidth >= 650 ? 3 : narrow ? 1 : 2,
                      mainAxisExtent: 158,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      return Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(table.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: ink, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 7),
                            Text(table.occupied ? 'Terisi (manual)' : 'Tersedia',
                                style: TextStyle(color: table.occupied ? Colors.deepOrange : primary, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: allowed ? () => store.setOccupied(outlet.selectedOutletId, table.id, !table.occupied) : null,
                                    child: Text(table.occupied ? 'Tersedia' : 'Terisi'),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Kelola ${table.name}',
                                  enabled: allowed,
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      editTable(table);
                                    } else if (action == 'delete') {
                                      deleteTable(table);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit Nama')),
                                    PopupMenuItem(value: 'delete', child: Text('Hapus Meja')),
                                  ],
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
