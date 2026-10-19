import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'table_store.dart';
import 'order_models.dart';
import 'order_store.dart';
import 'qr_actions.dart';

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
  final orderStore = FirefaOrderStore.instance;
  late final Future<void> ready;
  String search = '';
  String occupancyFilter = 'all';

  @override
  void initState() {
    super.initState();
    ready = Future.wait<void>([store.initialize(), orderStore.initialize()]).then((_) => orderStore.synchronizeTableOccupancy());
    outlet.addListener(refresh);
    store.addListener(refresh);
    orderStore.addListener(refresh);
  }

  void refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    outlet.removeListener(refresh);
    store.removeListener(refresh);
    orderStore.removeListener(refresh);
    super.dispose();
  }

  bool get allowed => FirefaAccess.can(outlet.role, FirefaPermission.tablesManage) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

  FirefaOrder? activeOrderFor(FirefaTable table) {
    for (final order in orderStore.ordersForOutlet(table.outletId)) {
      if (order.orderType == 'Dine In' &&
          order.tableId == table.name &&
          order.status != FirefaOrderStatus.completed &&
          order.status != FirefaOrderStatus.cancelled) {
        return order;
      }
    }
    return null;
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    final safe = escaped.isNotEmpty && '=+-@'.contains(escaped[0])
        ? "'$escaped" : escaped;
    return '"$safe"';
  }

  Future<void> _copyCsv(List<FirefaTable> rows) async {
    final selectedOutlet = outlet.selectedOutletId;
    if (!allowed || rows.any((t) => t.outletId != selectedOutlet)) {
      return;
    }
    final csv = <String>[
      'ID,Outlet ID,Nama Meja,Status',
      for (final table in rows)
        [table.id, table.outletId, table.name,
         table.occupied ? 'Terisi' : 'Tersedia'].map(_csvCell).join(','),
    ].join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted || !allowed || outlet.selectedOutletId != selectedOutlet) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('CSV ${rows.length} meja disalin ke clipboard.'),
    ));
  }

  String _selfOrderUrl(FirefaTable table) {
    final base = Uri.base.resolve('/firefa_customer_web/index.html');
    return base.replace(queryParameters: {
      'outletId': table.outletId,
      'tableId': table.id,
      'tableName': table.name,
    }).toString();
  }

  Future<void> createTableQr(FirefaTable table) async {
    if (!allowed || table.outletId != outlet.selectedOutletId) return;
    final sourceOutletId = table.outletId;
    final orderUrl = _selfOrderUrl(table);
    final qrUrl = Uri.https('api.qrserver.com', '/v1/create-qr-code/', {
      'size': '420x420',
      'margin': '12',
      'format': 'png',
      'data': orderUrl,
    }).toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('QR Pemesanan • ${table.name}'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(outlet.selectedOutletName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Image.network(
                    qrUrl,
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 260,
                      height: 120,
                      child: Center(child: Text(
                        'QR tidak dapat dimuat. Periksa koneksi internet.',
                        textAlign: TextAlign.center,
                      )),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(orderUrl,
                    style: const TextStyle(fontSize: 11, color: muted)),
                const SizedBox(height: 8),
                const Text(
                  'QR berisi ID outlet dan ID meja. Halaman pemesanan harus di-host pada alamat web FIREFA ini.',
                  style: TextStyle(fontSize: 12, color: muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: orderUrl));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tautan pemesanan disalin.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Salin tautan'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (!allowed || outlet.selectedOutletId != sourceOutletId) return;
              await FirefaQrActions.download(qrUrl, 'firefa-${table.id}-qr.png');
            },
            icon: const Icon(Icons.download),
            label: const Text('Unduh QR'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!allowed || outlet.selectedOutletId != sourceOutletId) return;
              await FirefaQrActions.print(qrUrl, table.name, outlet.selectedOutletName);
            },
            icon: const Icon(Icons.print),
            label: const Text('Cetak'),
          ),
        ],
      ),
    );
  }

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
        final query = search.trim().toLowerCase();
        final visible = tables.where((t) =>
            (occupancyFilter == 'all' ||
                (occupancyFilter == 'available' && !t.occupied) ||
                (occupancyFilter == 'occupied' && t.occupied)) &&
            (query.isEmpty || t.name.toLowerCase().contains(query))).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
                const Text('Status meja disinkronkan dengan pesanan dine-in aktif. Data tetap tersimpan lokal pada perangkat ini.',
                    style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(width: 240, child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Cari nama meja',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => search = value),
                  )),
                  DropdownButton<String>(
                    value: occupancyFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua meja')),
                      DropdownMenuItem(value: 'available', child: Text('Tersedia')),
                      DropdownMenuItem(value: 'occupied', child: Text('Terisi')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => occupancyFilter = value);
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: allowed ? () => _copyCsv(visible) : null,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text('Salin CSV (${visible.length})'),
                  ),
                  Text('Menampilkan ${visible.length} dari ${tables.length} meja'),
                ]),
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
                if (tables.isNotEmpty && visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Tidak ada meja yang sesuai filter.'),
                  ),
                if (visible.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 950 ? 4 : constraints.maxWidth >= 650 ? 3 : narrow ? 1 : 2,
                      mainAxisExtent: 252,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final table = visible[index];
                      final activeOrder = activeOrderFor(table);
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
                            Text(
                              activeOrder != null
                                  ? 'Terisi • Pesanan aktif'
                                  : table.occupied ? 'Terisi (manual)' : 'Tersedia',
                              style: TextStyle(
                                color: table.occupied ? Colors.deepOrange : primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (activeOrder != null) ...[
                              const SizedBox(height: 7),
                              Text(
                                '${activeOrder.id} • ${activeOrder.status.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${activeOrder.itemCount} item • Rp ${activeOrder.total}',
                                style: const TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: allowed ? () => createTableQr(table) : null,
                                    icon: const Icon(Icons.qr_code_2, size: 18),
                                    label: const Text('Buat QR'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: allowed && activeOrder == null ? () => store.setOccupied(outlet.selectedOutletId, table.id, !table.occupied) : null,
                                    child: Text(activeOrder != null ? 'Pesanan aktif' : table.occupied ? 'Tersedia' : 'Terisi'),
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
