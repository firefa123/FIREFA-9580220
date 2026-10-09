import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'settings_store.dart';

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
    ready = store.initialize();
    outlet.addListener(_refresh);
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
    footer.dispose();
    contact.dispose();
    address.dispose();
    super.dispose();
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tampilkan informasi pajak pada struk'),
                        subtitle: const Text('Preferensi tampilan saja; tidak mengubah perhitungan POS.'),
                        value: showTax,
                        activeThumbColor: primary,
                        onChanged: (value) => setState(() => showTax = value),
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
            ],
          );
        });
      },
    );
  }
}
