import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'printer_store.dart';

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final store = FirefaPrinterStore.instance;
  late final Future<void> ready;

  @override
  void initState() {
    super.initState();
    ready = store.initialize();
    store.addListener(_refresh);
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
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
          content: Text('Konfigurasi ${result.role.label} tersimpan lokal.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $error')),
      );
    }
  }

  void _testPrint(FirefaPrinterConfig config) {
    final message = !config.enabled
        ? 'Printer ${config.role.label} belum diaktifkan.'
        : config.target.trim().isEmpty
            ? 'Isi target/alamat printer terlebih dahulu.'
            : 'Test print ${config.name} disimulasikan ke ${config.target}.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
              'Konfigurasi printer outlet disimpan lokal pada perangkat ini.',
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
                    for (final config in store.configs)
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
