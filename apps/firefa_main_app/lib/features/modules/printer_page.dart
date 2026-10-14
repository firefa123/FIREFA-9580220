import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'printer_store.dart';

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final store = FirefaPrinterStore.instance;
  final outlet = FirefaActiveOutletStore.instance;
  late final Future<void> ready;

  @override
  void initState() {
    super.initState();
    ready = store.initialize();
    store.addListener(_refresh);
    outlet.addListener(_refresh);
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    outlet.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _edit(FirefaPrinterConfig config) async {
    final nameController = TextEditingController(text: config.name);
    final targetController = TextEditingController(text: config.target);
    var enabled = config.enabled;

    final result = await showDialog<FirefaPrinterConfig>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Printer ${config.role.label}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    subtitle: const Text(
                      'Aktifkan printer untuk kebutuhan outlet.',
                    ),
                    value: enabled,
                    onChanged: (value) => update(() => enabled = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Printer',
                      prefixIcon: Icon(Icons.print_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: targetController,
                    decoration: const InputDecoration(
                      labelText: 'Target / Alamat',
                      hintText: 'Contoh: 192.168.1.50 atau Bluetooth',
                      prefixIcon: Icon(Icons.link_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    config.copyWith(
                      name: nameController.text.trim().isEmpty
                          ? 'Printer ${config.role.label}'
                          : nameController.text.trim(),
                      target: targetController.text.trim(),
                      enabled: enabled,
                    ),
                  );
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    targetController.dispose();

    if (!mounted || result == null) return;

    try {
      await store.save(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Konfigurasi ${result.role.label} ${outlet.selectedOutletName} tersimpan lokal.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $error')),
      );
    }
  }

  Future<void> _testPrint(FirefaPrinterConfig config) async {
    if (!config.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printer ${config.role.label} belum diaktifkan.')),
      );
      return;
    }
    if (config.target.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi target/alamat printer terlebih dahulu.')),
      );
      return;
    }

    final lines = switch (config.role) {
      FirefaPrinterRole.cashier => [
          'FIREFA - TEST RECEIPT',
          '--------------------------------',
          'Outlet: ${outlet.selectedOutletName}',
          'No. Pesanan: TEST-0001',
          '1x Item Demo             Rp10.000',
          '--------------------------------',
          'TOTAL                    Rp10.000',
          'Metode: SIMULASI',
          'Terima kasih',
        ],
      FirefaPrinterRole.kitchen => [
          'FIREFA - KITCHEN TICKET',
          '--------------------------------',
          'Pesanan: TEST-0001',
          'Jenis: Dine In',
          '1x Item Demo',
          'CATATAN: Tiket uji coba',
          '--------------------------------',
          'BUKAN PESANAN AKTUAL',
        ],
      FirefaPrinterRole.bar => [
          'FIREFA - BAR TICKET',
          '--------------------------------',
          'Pesanan: TEST-0001',
          '1x Minuman Demo',
          'CATATAN: Tiket uji coba',
          '--------------------------------',
          'BUKAN PESANAN AKTUAL',
        ],
    };

    if (!mounted) return;
    final simulate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Preview test print - ${config.role.label}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Printer: ${config.name}'),
              const SizedBox(height: 4),
              Text(
                'Target: ${config.target}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  lines.join('\\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mode demo: preview ini belum mengirim data ke perangkat printer fisik.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Simulasikan'),
          ),
        ],
      ),
    );

    if (!mounted || simulate != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Preview ${config.role.label} berhasil disimulasikan. Printer fisik belum dihubungkan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Printer Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Konfigurasi printer ${outlet.selectedOutletName} disimpan lokal pada perangkat ini.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 32) / 3
                    : constraints.maxWidth >= 560
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final config in store.configsForOutlet(outlet.selectedOutletId))
                      SizedBox(
                        width: cardWidth,
                        child: _PrinterCard(
                          config: config,
                          onEdit: () => _edit(config),
                          onTest: () => _testPrint(config),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PrinterCard extends StatelessWidget {
  const _PrinterCard({
    required this.config,
    required this.onEdit,
    required this.onTest,
  });

  final FirefaPrinterConfig config;
  final VoidCallback onEdit;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final active = config.enabled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.print_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.green.withValues(alpha: 0.10)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                      color: active ? Colors.green.shade700 : Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              config.role.label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              config.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              config.target.isEmpty ? 'Belum ada target printer' : config.target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Atur'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onTest,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Test'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
