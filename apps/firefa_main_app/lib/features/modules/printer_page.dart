// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';

import '../../core/outlet/active_outlet_store.dart';
import '../../core/theme/app_theme.dart';
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
    String? validationError;

    final result = await showDialog<FirefaPrinterConfig>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Pengaturan Printer ' + config.role.label),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan printer'),
                  subtitle: Text('Printer untuk kebutuhan ' + config.role.label.toLowerCase() + '.'),
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
                  onChanged: (_) {
                    if (validationError != null) {
                      update(() => validationError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Alamat / Target Printer',
                    hintText: 'Contoh: alamat IP atau perangkat Bluetooth',
                    prefixIcon: const Icon(Icons.link_outlined),
                    errorText: validationError,
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
                if (enabled && targetController.text.trim().isEmpty) {
                  update(() => validationError =
                      'Target wajib diisi untuk printer aktif.');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  config.copyWith(
                    name: nameController.text.trim().isEmpty
                        ? 'Printer ' + config.role.label
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
      ),
    );

    nameController.dispose();
    targetController.dispose();
    if (!mounted || result == null) return;

    try {
      await store.save(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Konfigurasi printer ' + result.role.label.toLowerCase() + ' ' + outlet.selectedOutletName + ' tersimpan lokal.',
          ),
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
        SnackBar(content: Text('Printer ' + config.role.label.toLowerCase() + ' belum diaktifkan.')),
      );
      return;
    }
    if (config.target.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi alamat printer terlebih dahulu.')),
      );
      return;
    }

    const lines = [
      'FIREFA - TEST RECEIPT',
      '--------------------------------',
      'No. Pesanan: TEST-0001',
      '1x Item Demo             Rp10.000',
      '--------------------------------',
      'TOTAL                    Rp10.000',
      'Metode: SIMULASI',
      'Terima kasih',
    ];

    if (!mounted) return;
    final simulate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Preview Test Print - ' + config.role.label),
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
                  lines.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
          'Preview printer ' + config.role.label.toLowerCase() + ' disimulasikan. Printer fisik belum dihubungkan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Gagal memuat konfigurasi printer lokal.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final configs = store.configsForOutlet(outlet.selectedOutletId);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'Konfigurasi Printer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Konfigurasi printer kasir, dapur, dan bar untuk ${outlet.selectedOutletName}.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            for (final config in configs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _PrinterCard(
                    config: config,
                    onEdit: () => _edit(config),
                    onTest: () => _testPrint(config),
                  ),
                ),
              ),
            ],
          ),
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
                  child: const Icon(Icons.print_outlined, color: AppTheme.primary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
              'PRINTER ' + config.role.label.toUpperCase(),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              config.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              config.target.isEmpty ? 'Belum ada alamat printer' : config.target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
