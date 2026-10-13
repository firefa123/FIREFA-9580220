import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'settings_store.dart';
import 'local_backup_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const primary = Color(0xFF008F83);
  static const muted = Color(0xFF64748B);
  final outlet = FirefaActiveOutletStore.instance;
  final store = FirefaSettingsStore.instance;
  final backup = FirefaLocalBackupManager.instance;
  final footer = TextEditingController();
  final contact = TextEditingController();
  final address = TextEditingController();
  late final Future<void> ready;
  String? loadedOutlet;
  bool showTax = true;
  bool saving = false;

  bool get allowed => FirefaAccess.can(outlet.role, FirefaPermission.settingsManage) &&
      outlet.canAccessOutlet(outlet.selectedOutletId);

  @override
  void initState() {
    super.initState();
    ready = Future.wait([
      store.initialize(),
      backup.initialize(),
    ]);
    outlet.addListener(_refresh);
    backup.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _load(String id) {
    if (loadedOutlet == id) return;
    final value = store.forOutlet(id);
    loadedOutlet = id;
    footer.text = value.receiptFooter;
    contact.text = value.contact;
    address.text = value.address;
    showTax = value.showTaxOnReceipt;
  }

  @override
  void dispose() {
    outlet.removeListener(_refresh);
    backup.removeListener(_refresh);
    footer.dispose();
    contact.dispose();
    address.dispose();
    super.dispose();
  }

  String _formatBackupTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    final local = value.toLocal();
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _createBackup() async {
    try {
      final info = await backup.createBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup lokal dibuat: ${info.orderCount} order, '
            '${info.pendingEvents} event sync.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat backup: $error')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    if (backup.latest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada backup lokal untuk direstore.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Local Backup?'),
        content: const Text(
          'Data order dan antrean sync aktif akan diganti dengan snapshot '
          'backup terakhir. Gunakan hanya jika perlu memulihkan data lokal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final info = await backup.restoreLatestBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup ${_formatBackupTime(info.createdAt)} berhasil direstore.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore gagal: $error')),
      );
    }
  }

  Future<void> _save() async {
    if (saving || !allowed) return;
    final id = outlet.selectedOutletId;
    final value = FirefaOutletSettings(
      outletId: id,
      receiptFooter: footer.text.trim(),
      contact: contact.text.trim(),
      address: address.text.trim(),
      showTaxOnReceipt: showTax,
    );
    if (!store.update(id, value)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Periksa panjang input pengaturan.'),
      ));
      return;
    }
    setState(() => saving = true);
    try {
      await store.waitForPendingSave();
      if (!mounted || !allowed || outlet.selectedOutletId != id) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pengaturan outlet tersimpan secara lokal.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal menyimpan pengaturan lokal.'),
      ));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Gagal memuat pengaturan lokal. Data tidak ditimpa.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!allowed) {
          return const Text('Anda tidak memiliki akses mengubah Settings.');
        }
        final id = outlet.selectedOutletId;
        _load(id);
        return LayoutBuilder(builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings & Konfigurasi Outlet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${outlet.selectedOutletName} • ${outlet.role.label}',
                  style: const TextStyle(color: muted)),
              const SizedBox(height: 6),
              const Text('Pengaturan tersimpan di perangkat ini. Belum tersinkronisasi cloud. '
                  'Detail ini belum otomatis diterapkan ke struk POS.',
                  style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  padding: EdgeInsets.all(constraints.maxWidth < 500 ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Informasi Outlet & Preferensi Struk',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 18),
                      TextField(
                        controller: contact,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Kontak outlet',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: address,
                        maxLength: 240,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Alamat outlet',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: footer,
                        maxLength: 160,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Pesan penutup struk',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tampilkan informasi pajak pada struk'),
                          subtitle: const Text('Preferensi tampilan saja; tidak mengubah perhitungan POS.'),
                          value: showTax,
                          activeThumbColor: primary,
                          onChanged: (value) => setState(() => showTax = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: saving ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: primary),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Menyimpan...' : 'Simpan Pengaturan'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  padding: EdgeInsets.all(constraints.maxWidth < 500 ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local Backup',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        backup.latest == null
                            ? 'Belum ada backup lokal.'
                            : 'Backup terakhir: '
                              '${_formatBackupTime(backup.latest!.createdAt)} • '
                              '${backup.latest!.orderCount} order • '
                              '${backup.latest!.pendingEvents} event sync',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _createBackup,
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                            ),
                            icon: const Icon(Icons.backup_outlined),
                            label: const Text('Buat Backup Sekarang'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                backup.latest == null ? null : _restoreBackup,
                            icon: const Icon(Icons.restore_outlined),
                            label: const Text('Restore Backup'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Backup ini tersimpan di perangkat yang sama. '
                        'Belum dikirim ke cloud.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}
