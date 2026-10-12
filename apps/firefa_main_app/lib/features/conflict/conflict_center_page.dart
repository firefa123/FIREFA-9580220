import 'package:flutter/material.dart';
import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import '../modules/conflict_management.dart';
import '../modules/conflict_resolution_model.dart';
import '../modules/conflict_resolution_store.dart';
import '../modules/conflict_store.dart';

class ConflictCenterPage extends StatefulWidget {
  const ConflictCenterPage({super.key});
  @override
  State<ConflictCenterPage> createState() => _ConflictCenterPageState();
}

class _ConflictCenterPageState extends State<ConflictCenterPage> {
  final inbox = FirefaConflictStore.instance;
  final audit = ConflictResolutionStore.instance;
  final outlet = FirefaActiveOutletStore.instance;
  late final Future<void> ready;
  String? selectedId;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    ready = Future.wait([inbox.initialize(), audit.initialize()]);
    inbox.addListener(refresh);
    audit.addListener(refresh);
    outlet.addListener(refresh);
  }
  void refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    inbox.removeListener(refresh);
    audit.removeListener(refresh);
    outlet.removeListener(refresh);
    super.dispose();
  }

  List<FirefaSyncConflict> get items => inbox.conflicts
      .where((c) => c.outletId == outlet.selectedOutletId).toList()
    ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

  Future<void> decide(FirefaSyncConflict c, FirefaResolutionAction action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await audit.resolve(conflictId: c.eventId, action: action, actorId: outlet.role.label);
      if (action != FirefaResolutionAction.manualReview) await inbox.remove(c.eventId);
      if (!mounted) return;
      setState(() { saving = false; if (action != FirefaResolutionAction.manualReview) selectedId = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        action == FirefaResolutionAction.manualReview ? 'Review dicatat; konflik tetap terbuka.' : 'Keputusan tersimpan di audit lokal; data bisnis tidak diubah.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirefaAccess.can(outlet.role, FirefaPermission.conflictManage)) {
      return const Text('Anda tidak memiliki akses ke Conflict Center.');
    }
    return FutureBuilder<void>(
      future: ready,
      builder: (context, state) {
        if (state.hasError) return const Text('Gagal memuat Conflict Center lokal.');
        if (state.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final conflicts = items;
        final found = conflicts.where((c) => c.eventId == selectedId);
        final current = found.isEmpty ? null : found.first;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Conflict Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${outlet.selectedOutletName} • ${conflicts.length} konflik terbuka'),
          const SizedBox(height: 16),
          if (conflicts.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Tidak ada konflik terbuka untuk outlet ini.')))
          else LayoutBuilder(builder: (context, box) {
            final list = Card(child: Column(children: [
              const ListTile(title: Text('Conflict Inbox')),
              for (final c in conflicts)
                ListTile(
                  selected: c.eventId == selectedId,
                  leading: const Icon(Icons.sync_problem_outlined),
                  title: Text(c.kind.name),
                  subtitle: Text('Order ${c.orderId} • ${c.detectedAt.toLocal()}'),
                  onTap: () => setState(() => selectedId = c.eventId),
                ),
            ]));
            final detail = current == null
              ? const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Pilih konflik untuk melihat snapshot.')))
              : Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order ${current.orderId} • ${current.kind.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Snapshot lokal'),
                  SelectableText(current.localSnapshot.toString()),
                  const SizedBox(height: 8),
                  const Text('Snapshot server'),
                  SelectableText(current.serverSnapshot.toString()),
                  const SizedBox(height: 12),
                  const Text('Tindakan mencatat keputusan lokal; tidak mengubah order, stok, pembayaran, atau server.'),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(onPressed: saving ? null : () => decide(current, FirefaResolutionAction.manualReview), child: const Text('Manual Review')),
                    OutlinedButton(onPressed: saving ? null : () => decide(current, FirefaResolutionAction.keepLocal), child: const Text('Keep Local')),
                    FilledButton(onPressed: saving ? null : () async {
                      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                        title: const Text('Catat Accept Server?'),
                        content: const Text('Keputusan dicatat, tetapi snapshot bisnis tidak diubah.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjut'))],
                      ));
                      if (ok == true) await decide(current, FirefaResolutionAction.acceptServer);
                    }, child: const Text('Accept Server')),
                  ]),
                  if (saving) const LinearProgressIndicator(),
                ],
              )));
            if (box.maxWidth < 850) return Column(children: [list, detail]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 320, child: list), const SizedBox(width: 16), Expanded(child: detail)]);
          }),
          const SizedBox(height: 16),
          Card(child: Column(children: [
            const ListTile(title: Text('Audit Timeline Terbaru')),
            for (final record in audit.records.reversed.take(10))
              ListTile(leading: const Icon(Icons.history), title: Text('${record.action.name} • ${record.conflictId}'), subtitle: Text('${record.actorId} • ${record.resolvedAt.toLocal()}')),
          ])),
        ]);
      },
    );
  }
}
