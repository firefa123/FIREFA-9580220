import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/outlet/active_outlet_store.dart';
import 'order_models.dart';
import 'order_store.dart';

int calculateCashSalesForShift({
  required Iterable<FirefaOrder> orders,
  required DateTime openedAt,
  required DateTime closedAt,
}) {
  return orders.where((order) {
    final paidAt = order.paidAt;
    return order.paymentStatus == FirefaPaymentStatus.paid &&
        paidAt != null &&
        !paidAt.isBefore(openedAt) &&
        !paidAt.isAfter(closedAt);
  }).fold<int>(0, (sum, order) => sum + order.cashPaidAmount);
}

class FirefaCashierShift {
  final String id;
  final String outletId;
  final String cashierName;
  final DateTime openedAt;
  final int openingCash;
  final DateTime? closedAt;
  final int cashSales;
  final int cashIn;
  final int cashOut;
  final int? countedCash;

  const FirefaCashierShift({
    required this.id,
    required this.outletId,
    required this.cashierName,
    required this.openedAt,
    required this.openingCash,
    this.closedAt,
    this.cashSales = 0,
    this.cashIn = 0,
    this.cashOut = 0,
    this.countedCash,
  });

  bool get isOpen => closedAt == null;
  int get expectedCash => openingCash + cashSales + cashIn - cashOut;
  int? get difference => countedCash == null ? null : countedCash! - expectedCash;

  Map<String, dynamic> toJson() => {
        'id': id,
        'outletId': outletId,
        'cashierName': cashierName,
        'openedAt': openedAt.toIso8601String(),
        'openingCash': openingCash,
        'closedAt': closedAt?.toIso8601String(),
        'cashSales': cashSales,
        'cashIn': cashIn,
        'cashOut': cashOut,
        'countedCash': countedCash,
      };

  factory FirefaCashierShift.fromJson(Map<String, dynamic> json) {
    return FirefaCashierShift(
      id: json['id'] as String,
      outletId: json['outletId'] as String,
      cashierName: json['cashierName'] as String? ?? 'Kasir',
      openedAt: DateTime.parse(json['openedAt'] as String),
      openingCash: json['openingCash'] as int,
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      cashSales: json['cashSales'] as int? ?? 0,
      cashIn: json['cashIn'] as int? ?? 0,
      cashOut: json['cashOut'] as int? ?? 0,
      countedCash: json['countedCash'] as int?,
    );
  }
}

class FirefaCashierShiftStore extends ChangeNotifier {
  FirefaCashierShiftStore._();

  static final FirefaCashierShiftStore instance = FirefaCashierShiftStore._();
  static const _storageKey = 'firefa_cashier_shifts_v1';

  final List<FirefaCashierShift> _shifts = [];
  Future<void> _pendingSave = Future.value();
  bool _initialized = false;

  List<FirefaCashierShift> get shifts => List.unmodifiable(_shifts);

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List;
      final restored = decoded
          .map((entry) => FirefaCashierShift.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList();
      _shifts
        ..clear()
        ..addAll(restored);
    }
    _initialized = true;
  }

  FirefaCashierShift? activeForOutlet(String outletId) {
    _ensureInitialized();
    for (final shift in _shifts) {
      if (shift.outletId == outletId && shift.isOpen) return shift;
    }
    return null;
  }

  List<FirefaCashierShift> historyForOutlet(String outletId) {
    _ensureInitialized();
    return List.unmodifiable(
      _shifts.where((shift) => shift.outletId == outletId),
    );
  }

  FirefaCashierShift openShift({
    required String outletId,
    required int openingCash,
    String cashierName = 'Kasir',
    DateTime? openedAt,
  }) {
    _ensureInitialized();
    if (outletId.trim().isEmpty || openingCash < 0) {
      throw ArgumentError('Outlet dan modal awal yang valid wajib diisi.');
    }
    if (activeForOutlet(outletId) != null) {
      throw StateError('Shift outlet ini masih terbuka.');
    }
    final shift = FirefaCashierShift(
      id: 'SHIFT-${DateTime.now().microsecondsSinceEpoch}',
      outletId: outletId,
      cashierName: cashierName,
      openedAt: openedAt ?? DateTime.now(),
      openingCash: openingCash,
    );
    _shifts.insert(0, shift);
    _scheduleSave();
    notifyListeners();
    return shift;
  }

  FirefaCashierShift closeShift({
    required String shiftId,
    required int cashSales,
    required int cashIn,
    required int cashOut,
    required int countedCash,
    DateTime? closedAt,
  }) {
    _ensureInitialized();
    if (cashSales < 0 || cashIn < 0 || cashOut < 0 || countedCash < 0) {
      throw ArgumentError('Nominal kas tidak boleh negatif.');
    }
    final index = _shifts.indexWhere((shift) => shift.id == shiftId);
    if (index < 0 || !_shifts[index].isOpen) {
      throw StateError('Shift aktif tidak ditemukan.');
    }
    final old = _shifts[index];
    if (cashOut > old.openingCash + cashSales + cashIn) {
      throw ArgumentError('Kas keluar melebihi uang yang tersedia pada shift.');
    }
    final closed = FirefaCashierShift(
      id: old.id,
      outletId: old.outletId,
      cashierName: old.cashierName,
      openedAt: old.openedAt,
      openingCash: old.openingCash,
      closedAt: closedAt ?? DateTime.now(),
      cashSales: cashSales,
      cashIn: cashIn,
      cashOut: cashOut,
      countedCash: countedCash,
    );
    _shifts[index] = closed;
    _scheduleSave();
    notifyListeners();
    return closed;
  }

  Future<void> waitForPendingSave() => _pendingSave;

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('FirefaCashierShiftStore.initialize() harus dipanggil.');
    }
  }

  void _scheduleSave() {
    final snapshot = jsonEncode(_shifts.map((shift) => shift.toJson()).toList());
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(_storageKey, snapshot);
      if (!saved) throw StateError('Gagal menyimpan shift kasir.');
    });
  }
}

class CashierShiftPage extends StatefulWidget {
  const CashierShiftPage({super.key});

  @override
  State<CashierShiftPage> createState() => _CashierShiftPageState();
}

class _CashierShiftPageState extends State<CashierShiftPage> {
  final _store = FirefaCashierShiftStore.instance;
  final _openingController = TextEditingController();
  final _cashInController = TextEditingController(text: '0');
  final _cashOutController = TextEditingController(text: '0');
  final _countedController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _store.initialize();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _openingController.dispose();
    _cashInController.dispose();
    _cashOutController.dispose();
    _countedController.dispose();
    super.dispose();
  }

  int _number(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? -1;

  String _money(int value) => 'Rp ${value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      )}';

  Future<void> _openShift() async {
    final amount = _number(_openingController);
    if (amount < 0) {
      _message('Isi modal awal dengan angka nol atau lebih.');
      return;
    }
    setState(() => _saving = true);
    try {
      _store.openShift(
        outletId: FirefaActiveOutletStore.instance.selectedOutletId,
        openingCash: amount,
      );
      await _store.waitForPendingSave();
      _openingController.clear();
      _message('Shift kasir berhasil dibuka.');
    } catch (error) {
      _message(error is StateError ? error.message : 'Gagal membuka shift.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _cashSalesForShift(FirefaCashierShift shift, {DateTime? until}) {
    return calculateCashSalesForShift(
      orders: FirefaOrderStore.instance.ordersForOutlet(shift.outletId),
      openedAt: shift.openedAt,
      closedAt: until ?? DateTime.now(),
    );
  }

  Future<void> _closeShift(FirefaCashierShift shift) async {
    final closingTime = DateTime.now();
    final cashSales = _cashSalesForShift(shift, until: closingTime);
    final cashIn = _number(_cashInController);
    final cashOut = _number(_cashOutController);
    final counted = _number(_countedController);
    if ([cashIn, cashOut, counted].any((value) => value < 0)) {
      _message('Semua nominal penutupan wajib diisi dengan angka nol atau lebih.');
      return;
    }
    setState(() => _saving = true);
    try {
      final closed = _store.closeShift(
        shiftId: shift.id,
        cashSales: cashSales,
        cashIn: cashIn,
        cashOut: cashOut,
        countedCash: counted,
        closedAt: closingTime,
      );
      await _store.waitForPendingSave();
      _cashInController.text = '0';
      _cashOutController.text = '0';
      _countedController.clear();
      _message('Shift ditutup. Selisih kas: ${_money(closed.difference ?? 0)}');
    } catch (error) {
      _message(error is StateError
          ? error.message
          : error is ArgumentError
              ? error.message.toString()
              : 'Gagal menutup shift.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _amountField(
    String label,
    TextEditingController controller, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      onChanged: (_) { if (mounted) setState(() {}); },
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final outletId = FirefaActiveOutletStore.instance.selectedOutletId;
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final current = _store.activeForOutlet(outletId);
        final records = _store.historyForOutlet(outletId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.point_of_sale_outlined, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            current == null ? 'Buka Shift Kasir' : 'Shift Sedang Berjalan',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Chip(label: Text(current == null ? 'Tertutup' : 'Aktif')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Outlet: ${FirefaActiveOutletStore.instance.selectedOutletName}'),
                    const SizedBox(height: 16),
                    if (current == null) ...[
                      _amountField('Modal awal kas', _openingController, autofocus: true),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _openShift,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Buka Shift'),
                      ),
                    ] else ...[
                      Text('Dibuka: ${current.openedAt.toLocal()}'),
                      const SizedBox(height: 8),
                      Text('Modal awal: ${_money(current.openingCash)}'),
                      const SizedBox(height: 16),
                      const Text(
                        'Penjualan tunai dihitung otomatis dari transaksi yang dibayar dengan tunai atau bagian tunai dari split payment selama shift ini.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Penjualan tunai otomatis: ${_money(_cashSalesForShift(current))}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      _amountField('Kas masuk tambahan', _cashInController),
                      const SizedBox(height: 10),
                      _amountField('Kas keluar', _cashOutController),
                      const SizedBox(height: 10),
                      _amountField('Uang fisik saat tutup', _countedController),
                      const SizedBox(height: 12),
                      Text(
                        'Estimasi kas: ${_money(current.openingCash + _cashSalesForShift(current) + (_number(_cashInController) < 0 ? 0 : _number(_cashInController)) - (_number(_cashOutController) < 0 ? 0 : _number(_cashOutController)))}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _closeShift(current),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Tutup Shift & Rekonsiliasi'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Riwayat Shift', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (records.isEmpty)
              const Card(child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Belum ada riwayat shift pada outlet ini.'),
              ))
            else
              for (final shift in records)
                Card(
                  child: ListTile(
                    leading: Icon(shift.isOpen ? Icons.lock_open : Icons.lock_outline),
                    title: Text('${shift.cashierName} • ${shift.isOpen ? 'Aktif' : 'Ditutup'}'),
                    subtitle: Text(
                      '${shift.openedAt.toLocal()} • Modal ${_money(shift.openingCash)}'
                      '${shift.isOpen ? '' : '\nEkspektasi ${_money(shift.expectedCash)} • Fisik ${_money(shift.countedCash ?? 0)} • Selisih ${_money(shift.difference ?? 0)}'}',
                    ),
                    isThreeLine: !shift.isOpen,
                  ),
                ),
            const SizedBox(height: 8),
            const Text(
              'Mode lokal: data tersimpan di perangkat ini. Pembayaran QRIS/transfer tidak menambah estimasi uang fisik. Transaksi lama tanpa waktu/metode pembayaran tidak dihitung otomatis.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
