import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _teal = Color(0xFF008F83);
const _ink = Color(0xFF172B4D);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _bg = Color(0xFFF5F7FA);
const _storeKey = 'firefa.rebuild.local.v1';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FirefaRebuildApp());
}

class MenuProduct {
  final String id;
  String name;
  String category;
  int price;
  int stock;

  MenuProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'stock': stock,
      };

  factory MenuProduct.fromJson(Map<String, dynamic> json) => MenuProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        price: (json['price'] as num).toInt(),
        stock: (json['stock'] as num).toInt(),
      );
}

class OrderLine {
  final String productId;
  final String name;
  final int price;
  final int quantity;

  const OrderLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  int get total => price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        productId: json['productId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toInt(),
        quantity: (json['quantity'] as num).toInt(),
      );
}

class LocalOrder {
  final String id;
  final DateTime createdAt;
  final String type;
  final String? table;
  final List<OrderLine> lines;
  String status;
  final bool paid;
  bool stockRestored;

  LocalOrder({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.table,
    required this.lines,
    this.status = 'Baru',
    this.paid = true,
    this.stockRestored = false,
  });

  int get total => lines.fold(0, (sum, line) => sum + line.total);
  bool get active => status != 'Selesai' && status != 'Dibatalkan';

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'type': type,
        'table': table,
        'lines': lines.map((line) => line.toJson()).toList(),
        'status': status,
        'paid': paid,
        'stockRestored': stockRestored,
      };

  factory LocalOrder.fromJson(Map<String, dynamic> json) => LocalOrder(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        type: json['type'] as String,
        table: json['table'] as String?,
        lines: (json['lines'] as List<dynamic>)
            .map((line) => OrderLine.fromJson(
                Map<String, dynamic>.from(line as Map)))
            .toList(),
        status: json['status'] as String,
        paid: json['paid'] as bool? ?? false,
        stockRestored: json['stockRestored'] as bool? ?? false,
      );
}

/// Small local-first store for the first functional milestone.
/// It intentionally does not pretend to be connected to a cloud backend.
class FirefaLocalStore extends ChangeNotifier {
  FirefaLocalStore({SharedPreferences? preferences})
      : _providedPreferences = preferences;

  final SharedPreferences? _providedPreferences;
  SharedPreferences? _preferences;
  bool _initialized = false;
  int _orderSequence = 1;
  String businessName = 'FIREFA Demo Restaurant';
  String receiptFooter = 'Terima kasih atas kunjungan Anda.';
  final Map<String, String> printerTargets = {
    'Kasir': '',
    'Kitchen': '',
    'Bar': '',
  };
  final Map<String, bool> printerEnabled = {
    'Kasir': false,
    'Kitchen': false,
    'Bar': false,
  };

  final List<MenuProduct> products = [
    MenuProduct(id: 'P01', name: 'Cappuccino', category: 'Coffee', price: 28000, stock: 40),
    MenuProduct(id: 'P02', name: 'Cafe Latte', category: 'Coffee', price: 30000, stock: 35),
    MenuProduct(id: 'P03', name: 'Americano', category: 'Coffee', price: 24000, stock: 45),
    MenuProduct(id: 'P04', name: 'Matcha Latte', category: 'Non Coffee', price: 32000, stock: 25),
    MenuProduct(id: 'P05', name: 'Chocolate Ice', category: 'Non Coffee', price: 29000, stock: 30),
    MenuProduct(id: 'P06', name: 'Nasi Goreng', category: 'Food', price: 38000, stock: 20),
    MenuProduct(id: 'P07', name: 'Chicken Katsu', category: 'Food', price: 42000, stock: 18),
    MenuProduct(id: 'P08', name: 'French Fries', category: 'Snacks', price: 25000, stock: 25),
  ];

  final List<LocalOrder> orders = [];
  final List<String> tables = List<String>.generate(12, (index) => 'T${index + 1}');

  Future<void> initialize() async {
    if (_initialized) return;
    _preferences = _providedPreferences ?? await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_storeKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final savedProducts = (data['products'] as List<dynamic>?)
            ?.map((item) => MenuProduct.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        final savedOrders = (data['orders'] as List<dynamic>?)
            ?.map((item) => LocalOrder.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        if (savedProducts != null && savedProducts.isNotEmpty) {
          products
            ..clear()
            ..addAll(savedProducts);
        }
        if (savedOrders != null) {
          orders
            ..clear()
            ..addAll(savedOrders);
        }
        _orderSequence = (data['orderSequence'] as num?)?.toInt() ?? 1;
        businessName = data['businessName'] as String? ?? businessName;
        receiptFooter = data['receiptFooter'] as String? ?? receiptFooter;
        final savedTargets = data['printerTargets'];
        if (savedTargets is Map) {
          for (final role in printerTargets.keys) {
            printerTargets[role] = savedTargets[role] as String? ?? '';
          }
        }
        final savedEnabled = data['printerEnabled'];
        if (savedEnabled is Map) {
          for (final role in printerEnabled.keys) {
            printerEnabled[role] = savedEnabled[role] as bool? ?? false;
          }
        }
      } catch (_) {
        // Invalid local data must not stop the app from opening with defaults.
      }
    }
    _initialized = true;
  }

  Future<void> _save() async {
    final prefs = _preferences;
    if (prefs == null) throw StateError('Data lokal belum diinisialisasi.');
    final encoded = jsonEncode({
      'products': products.map((product) => product.toJson()).toList(),
      'orders': orders.map((order) => order.toJson()).toList(),
      'orderSequence': _orderSequence,
      'businessName': businessName,
      'receiptFooter': receiptFooter,
      'printerTargets': printerTargets,
      'printerEnabled': printerEnabled,
    });
    final saved = await prefs.setString(_storeKey, encoded);
    if (!saved) throw StateError('Gagal menyimpan data lokal.');
  }

  Future<LocalOrder> checkout({
    required Map<String, int> quantities,
    required String type,
    String? table,
  }) async {
    if (quantities.isEmpty) throw StateError('Keranjang masih kosong.');
    if (type == 'Dine In' && (table == null || isTableOccupied(table))) {
      throw StateError('Meja belum dipilih atau sudah terisi.');
    }
    for (final entry in quantities.entries) {
      final product = products.firstWhere(
        (item) => item.id == entry.key,
        orElse: () => throw StateError('Menu tidak ditemukan.'),
      );
      if (entry.value < 1) throw StateError('Jumlah pesanan tidak valid.');
      if (product.stock < entry.value) {
        throw StateError('Stok ${product.name} tidak mencukupi.');
      }
    }

    final lines = quantities.entries.map((entry) {
      final product = products.firstWhere((item) => item.id == entry.key);
      return OrderLine(
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: entry.value,
      );
    }).toList();

    for (final entry in quantities.entries) {
      products.firstWhere((item) => item.id == entry.key).stock -= entry.value;
    }
    final order = LocalOrder(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch}-$_orderSequence',
      createdAt: DateTime.now(),
      type: type,
      table: type == 'Dine In' ? table : null,
      lines: lines,
    );
    _orderSequence++;
    orders.insert(0, order);
    try {
      await _save();
    } catch (_) {
      orders.remove(order);
      for (final entry in quantities.entries) {
        products.firstWhere((item) => item.id == entry.key).stock += entry.value;
      }
      _orderSequence--;
      rethrow;
    }
    notifyListeners();
    return order;
  }

  Future<void> advanceOrder(LocalOrder order) async {
    const next = {
      'Baru': 'Diproses',
      'Diproses': 'Siap Disajikan',
      'Siap Disajikan': 'Selesai',
    };
    final previous = order.status;
    final updated = next[previous];
    if (updated == null) return;
    order.status = updated;
    try {
      await _save();
    } catch (_) {
      order.status = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> cancelOrder(LocalOrder order) async {
    if (!order.active) return;
    final previousStatus = order.status;
    order.status = 'Dibatalkan';
    if (!order.stockRestored) {
      for (final line in order.lines) {
        final product = products.firstWhere(
          (item) => item.id == line.productId,
          orElse: () => MenuProduct(
            id: line.productId,
            name: line.name,
            category: 'Other',
            price: line.price,
            stock: 0,
          ),
        );
        if (products.any((item) => item.id == line.productId)) {
          product.stock += line.quantity;
        }
      }
      order.stockRestored = true;
    }
    try {
      await _save();
    } catch (_) {
      order.status = previousStatus;
      order.stockRestored = false;
      for (final line in order.lines) {
        final matches = products.where((item) => item.id == line.productId);
        if (matches.isNotEmpty) matches.first.stock -= line.quantity;
      }
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveMenuProduct({
    String? id,
    required String name,
    required String category,
    required int price,
    required int openingStock,
  }) async {
    final normalizedName = name.trim();
    final normalizedCategory = category.trim();
    if (normalizedName.isEmpty || normalizedCategory.isEmpty) {
      throw StateError('Nama menu dan kategori wajib diisi.');
    }
    if (price < 1 || openingStock < 0) {
      throw StateError('Harga harus lebih dari nol dan stok tidak boleh negatif.');
    }
    if (products.any((item) =>
        item.id != id && item.name.toLowerCase() == normalizedName.toLowerCase())) {
      throw StateError('Nama menu sudah digunakan.');
    }
    final existing = id == null ? null : products.firstWhere(
      (item) => item.id == id,
      orElse: () => throw StateError('Menu tidak ditemukan.'),
    );
    final oldName = existing?.name;
    final oldCategory = existing?.category;
    final oldPrice = existing?.price;
    final oldStock = existing?.stock;
    if (existing == null) {
      final nextId = 'P${products.length + 1}';
      products.add(MenuProduct(
        id: nextId,
        name: normalizedName,
        category: normalizedCategory,
        price: price,
        stock: openingStock,
      ));
    } else {
      existing
        ..name = normalizedName
        ..category = normalizedCategory
        ..price = price
        ..stock = openingStock;
    }
    try {
      await _save();
    } catch (_) {
      if (existing == null) {
        products.removeLast();
      } else {
        existing
          ..name = oldName!
          ..category = oldCategory!
          ..price = oldPrice!
          ..stock = oldStock!;
      }
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveBusinessSettings({
    required String name,
    required String footer,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw StateError('Nama restoran wajib diisi.');
    final previousName = businessName;
    final previousFooter = receiptFooter;
    businessName = cleanName;
    receiptFooter = footer.trim();
    try {
      await _save();
    } catch (_) {
      businessName = previousName;
      receiptFooter = previousFooter;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> savePrinterSettings({
    required String role,
    required bool enabled,
    required String target,
  }) async {
    if (!printerTargets.containsKey(role)) throw StateError('Jenis printer tidak dikenal.');
    if (enabled && target.trim().isEmpty) {
      throw StateError('Isi nama/alamat printer sebelum mengaktifkannya.');
    }
    final previousEnabled = printerEnabled[role]!;
    final previousTarget = printerTargets[role]!;
    printerEnabled[role] = enabled;
    printerTargets[role] = target.trim();
    try {
      await _save();
    } catch (_) {
      printerEnabled[role] = previousEnabled;
      printerTargets[role] = previousTarget;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> receiveStock(MenuProduct product, int quantity) async {
    if (quantity < 1) throw StateError('Jumlah stok harus lebih dari nol.');
    product.stock += quantity;
    try {
      await _save();
    } catch (_) {
      product.stock -= quantity;
      rethrow;
    }
    notifyListeners();
  }

  int get activeOrders => orders.where((order) => order.active).length;
  int get totalSales => orders
      .where((order) => order.status != 'Dibatalkan')
      .fold(0, (sum, order) => sum + order.total);

  bool isTableOccupied(String table) => orders.any((order) =>
      order.type == 'Dine In' && order.table == table && order.active);
}

class FirefaRebuildApp extends StatefulWidget {
  const FirefaRebuildApp({super.key});

  @override
  State<FirefaRebuildApp> createState() => _FirefaRebuildAppState();
}

class _FirefaRebuildAppState extends State<FirefaRebuildApp> {
  late final FirefaLocalStore store;
  late final Future<void> ready;

  @override
  void initState() {
    super.initState();
    store = FirefaLocalStore();
    ready = store.initialize();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIREFA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _teal, brightness: Brightness.light)
            .copyWith(primary: _teal, onPrimary: Colors.white),
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _ink, elevation: 0),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _line),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: FutureBuilder<void>(
        future: ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text('Gagal membuka FIREFA: ${snapshot.error}')));
          }
          return RoleEntryPage(store: store);
        },
      ),
    );
  }
}

class RoleEntryPage extends StatefulWidget {
  final FirefaLocalStore store;
  const RoleEntryPage({super.key, required this.store});

  @override
  State<RoleEntryPage> createState() => _RoleEntryPageState();
}

class _RoleEntryPageState extends State<RoleEntryPage> {
  String role = 'Owner';
  final nameController = TextEditingController(text: 'Demo User');

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, size: 58, color: _teal),
                      const SizedBox(height: 12),
                      const Text('FIREFA', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: _ink, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      const Text('Restaurant Operating System', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
                      const SizedBox(height: 28),
                      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama pengguna', prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Masuk sebagai', prefixIcon: Icon(Icons.badge_outlined)),
                        items: const [
                          DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                          DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                          DropdownMenuItem(value: 'Kasir', child: Text('Kasir')),
                          DropdownMenuItem(value: 'Kitchen/Bar', child: Text('Kitchen / Bar')),
                        ],
                        onChanged: (value) => setState(() => role = value ?? 'Owner'),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (_) => MainShell(store: widget.store, role: role, userName: name.isEmpty ? role : name),
                          ));
                        },
                        child: const Text('Masuk ke FIREFA'),
                      ),
                      const SizedBox(height: 12),
                      const Text('Mode demo lokal • autentikasi server belum terhubung', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final FirefaLocalStore store;
  final String role;
  final String userName;

  const MainShell({super.key, required this.store, required this.role, required this.userName});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;

  List<_NavItem> get navigation {
    if (widget.role == 'Kasir') {
      return const [_NavItem('POS', Icons.point_of_sale), _NavItem('Pesanan', Icons.receipt_long), _NavItem('Meja', Icons.table_restaurant)];
    }
    if (widget.role == 'Kitchen/Bar') {
      return const [_NavItem('Pesanan', Icons.receipt_long), _NavItem('Meja', Icons.table_restaurant)];
    }
    return const [
      _NavItem('Dashboard', Icons.dashboard_outlined),
      _NavItem('POS', Icons.point_of_sale),
      _NavItem('Pesanan', Icons.receipt_long),
      _NavItem('Meja', Icons.table_restaurant),
      _NavItem('Menu', Icons.restaurant_menu),
      _NavItem('Inventory', Icons.inventory_2_outlined),
      _NavItem('Laporan', Icons.bar_chart),
      _NavItem('Printer', Icons.print_outlined),
      _NavItem('Pengaturan', Icons.settings_outlined),
    ];
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Widget _page(String label) {
    switch (label) {
      case 'Dashboard':
        return DashboardView(store: widget.store, userName: widget.userName, role: widget.role);
      case 'POS':
        return PosView(store: widget.store);
      case 'Pesanan':
        return OrdersView(store: widget.store, kitchenMode: widget.role == 'Kitchen/Bar');
      case 'Meja':
        return TablesView(store: widget.store);
      case 'Menu':
        return MenuView(store: widget.store);
      case 'Inventory':
        return InventoryView(store: widget.store);
      case 'Laporan':
        return ReportsView(store: widget.store);
      case 'Printer':
        return PrinterView(store: widget.store);
      case 'Pengaturan':
        return BusinessSettingsView(store: widget.store);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = navigation;
    if (selected >= items.length) selected = 0;
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.restaurant_menu_rounded, color: _teal),
          const SizedBox(width: 10),
          const Text('FIREFA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(20)), child: Text(widget.role, style: const TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w700))),
        ]),
        actions: [
          if (!compact) Padding(padding: const EdgeInsets.only(right: 20), child: Center(child: Text(widget.userName, style: const TextStyle(color: _muted)))),
          IconButton(tooltip: 'Keluar', onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => RoleEntryPage(store: widget.store)), (_) => false), icon: const Icon(Icons.logout)),
        ],
      ),
      body: Row(
        children: [
          if (!compact) NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: (value) => setState(() => selected = value),
            labelType: NavigationRailLabelType.all,
            destinations: [for (final item in items) NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label))],
          ),
          if (!compact) const VerticalDivider(width: 1, color: _line),
          Expanded(child: _page(items[selected].label)),
        ],
      ),
      bottomNavigationBar: compact ? NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (value) => setState(() => selected = value),
        destinations: [for (final item in items) NavigationDestination(icon: Icon(item.icon), label: item.label)],
      ) : null,
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class PageFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const PageFrame({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: _muted)),
          const SizedBox(height: 22),
          child,
        ]),
      ),
    ),
  );
}

class DashboardView extends StatelessWidget {
  final FirefaLocalStore store;
  final String userName;
  final String role;
  const DashboardView({super.key, required this.store, required this.userName, required this.role});

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Dashboard',
    subtitle: 'Ringkasan operasional hari ini, $userName.',
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _MetricCard(label: 'Pesanan Aktif', value: '${store.activeOrders}', icon: Icons.receipt_long, note: 'Belum selesai'),
        _MetricCard(label: 'Total Penjualan', value: _rupiah(store.totalSales), icon: Icons.payments_outlined, note: 'Pesanan tidak dibatalkan'),
        _MetricCard(label: 'Item Menu', value: '${store.products.length}', icon: Icons.restaurant_menu, note: 'Menu terdaftar'),
        _MetricCard(label: 'Stok Menipis', value: '${store.products.where((p) => p.stock <= 5).length}', icon: Icons.inventory_2_outlined, note: 'Stok ≤ 5 unit'),
      ]),
      const SizedBox(height: 16),
      const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Alur utama: POS → Pesanan → Meja dan Inventory. Data tersimpan di perangkat ini.'))),
    ]),
  );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String note;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.note});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: _teal), const Spacer(), Text(note, style: const TextStyle(fontSize: 10, color: _muted))]),
      const SizedBox(height: 18),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: _muted)),
    ]))),
  );
}

String _rupiah(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer('Rp ');
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
  }
  return buffer.toString();
}

class PosView extends StatefulWidget {
  final FirefaLocalStore store;
  const PosView({super.key, required this.store});

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final Map<String, int> cart = {};
  String category = 'Semua';
  String type = 'Dine In';
  String? table;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final categories = ['Semua', ...widget.store.products.map((p) => p.category).toSet()];
    final visible = widget.store.products.where((p) => category == 'Semua' || p.category == category).toList();
    final total = cart.entries.fold<int>(0, (sum, entry) {
      final product = widget.store.products.firstWhere((p) => p.id == entry.key);
      return sum + product.price * entry.value;
    });
    return PageFrame(
      title: 'Point of Sale',
      subtitle: 'Pilih menu, atur jumlah, lalu buat pesanan.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [for (final item in categories) ChoiceChip(label: Text(item), selected: category == item, onSelected: (_) => setState(() => category = item))]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 950 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: [for (final product in visible) Card(child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: product.stock <= (cart[product.id] ?? 0)
                  ? null
                  : () => setState(() => cart.update(product.id, (qty) => qty + 1, ifAbsent: () => 1)),
              child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant, color: _teal)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                  Text(_rupiah(product.price), style: const TextStyle(color: _teal, fontWeight: FontWeight.w700)),
                  Text('Stok: ${product.stock}', style: const TextStyle(fontSize: 11, color: _muted)),
                ])),
                if ((cart[product.id] ?? 0) > 0) Text('×${cart[product.id]}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ])),
            ))],
          );
        }),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ringkasan Pesanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 10),
          if (cart.isEmpty) const Text('Keranjang masih kosong.', style: TextStyle(color: _muted)),
          for (final entry in cart.entries) Builder(builder: (context) {
            final product = widget.store.products.firstWhere((p) => p.id == entry.key);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(product.name),
              subtitle: Text('${entry.value} × ${_rupiah(product.price)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(onPressed: () => setState(() { if (entry.value <= 1) { cart.remove(entry.key); } else { cart[entry.key] = entry.value - 1; } }), icon: const Icon(Icons.remove_circle_outline)),
                IconButton(onPressed: product.stock <= entry.value ? null : () => setState(() => cart[entry.key] = entry.value + 1), icon: const Icon(Icons.add_circle_outline)),
              ]),
            );
          }),
          const Divider(),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Jenis pesanan'), items: const [DropdownMenuItem(value: 'Dine In', child: Text('Dine In')), DropdownMenuItem(value: 'Take Away', child: Text('Take Away'))], onChanged: (value) => setState(() { type = value ?? 'Dine In'; if (type != 'Dine In') table = null; })),
          if (type == 'Dine In') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: table, decoration: const InputDecoration(labelText: 'Pilih meja'), items: [for (final t in widget.store.tables.where((t) => !widget.store.isTableOccupied(t))) DropdownMenuItem(value: t, child: Text(t))], onChanged: (value) => setState(() => table = value)),
          ],
          const SizedBox(height: 12),
          Row(children: [const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))), Text(_rupiah(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _teal))]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving || cart.isEmpty || (type == 'Dine In' && table == null) ? null : () async {
              setState(() => saving = true);
              try {
                final order = await widget.store.checkout(quantities: Map<String, int>.from(cart), type: type, table: table);
                if (!context.mounted) return;
                setState(() { cart.clear(); table = null; });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pesanan ${order.id} berhasil dibuat. Pembayaran demo tercatat Paid.')));
              } catch (error) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout gagal: $error')));
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
            icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline),
            label: Text(saving ? 'Menyimpan...' : 'Buat Pesanan'),
          ),
          const SizedBox(height: 6),
          const Text('Pembayaran saat ini simulasi lokal; belum terhubung ke QRIS/bank.', style: TextStyle(fontSize: 11, color: _muted)),
        ]))),
      ]),
    );
  }
}

class OrdersView extends StatelessWidget {
  final FirefaLocalStore store;
  final bool kitchenMode;
  const OrdersView({super.key, required this.store, this.kitchenMode = false});

  String _receiptText(LocalOrder order) {
    final buffer = StringBuffer()
      ..writeln(store.businessName)
      ..writeln('Struk transaksi lokal')
      ..writeln('--------------------------------')
      ..writeln('Order: ${order.id}')
      ..writeln('Tanggal: ${order.createdAt.toLocal()}')
      ..writeln('Jenis: ${order.type}${order.table == null ? '' : ' / Meja ${order.table}'}')
      ..writeln('Status: ${order.status}')
      ..writeln('Pembayaran: ${order.paid ? 'Paid (demo)' : 'Unpaid'}')
      ..writeln('--------------------------------');
    for (final line in order.lines) {
      buffer.writeln('${line.name} x${line.quantity}');
      buffer.writeln('  ${_rupiah(line.total)}');
    }
    buffer
      ..writeln('--------------------------------')
      ..writeln('TOTAL: ${_rupiah(order.total)}')
      ..writeln(store.receiptFooter)
      ..writeln('Pembayaran demo; bukan bukti settlement bank.');
    return buffer.toString();
  }

  Future<void> _showReceipt(BuildContext context, LocalOrder order) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(store.businessName),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: SelectableText(_receiptText(order), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _receiptText(order)));
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Struk disalin ke clipboard.')));
              }
            },
            child: const Text('Salin Struk'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final doc = pw.Document();
              doc.addPage(pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (_) => pw.Padding(
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Text(_receiptText(order), style: pw.TextStyle(fontSize: 10, font: pw.Font.courier())),
                ),
              ));
              try {
                await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'FIREFA-${order.id}.pdf');
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka cetak: $error')));
                }
              }
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Cetak / Simpan PDF'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = kitchenMode
        ? store.orders.where((order) => order.active).toList()
        : store.orders;

    return PageFrame(
      title: kitchenMode ? 'Antrean Kitchen / Bar' : 'Manajemen Pesanan',
      subtitle: 'Perubahan status tersimpan di perangkat ini.',
      child: visible.isEmpty
          ? const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text('Belum ada pesanan.')),
              ),
            )
          : Column(
              children: [
                for (final order in visible)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                              ),
                              Chip(label: Text(order.status)),
                            ],
                          ),
                          Text(
                            '${order.type}${order.table == null ? '' : ' • Meja ${order.table}'} • ${order.paid ? 'Paid (demo)' : 'Unpaid'}',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          for (final line in order.lines)
                            Text('${line.quantity}× ${line.name} — ${_rupiah(line.total)}'),
                          const Divider(),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                _rupiah(order.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showReceipt(context, order),
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Struk'),
                              ),
                              if (order.active)
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await store.cancelOrder(order);
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Pembatalan gagal: $error')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Batalkan'),
                                ),
                              if (order.active)
                                FilledButton(
                                  onPressed: () async {
                                    try {
                                      await store.advanceOrder(order);
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Status gagal disimpan: $error')),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(_nextStatusLabel(order.status)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _nextStatusLabel(String status) => switch (status) {
    'Baru' => 'Mulai Proses',
    'Diproses' => 'Siap Disajikan',
    'Siap Disajikan' => 'Selesaikan',
    _ => 'Selesai',
  };
}

class TablesView extends StatelessWidget {
  final FirefaLocalStore store;
  const TablesView({super.key, required this.store});

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Manajemen Meja',
    subtitle: 'Status meja mengikuti pesanan Dine In yang masih aktif.',
    child: LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 550 ? 3 : 2;
      return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: columns, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.45, children: [
        for (final table in store.tables) Builder(builder: (context) {
          final occupied = store.isTableOccupied(table);
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.table_restaurant, color: occupied ? Colors.orange : _teal, size: 28),
            const Spacer(),
            Text(table, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
            Text(occupied ? 'Terisi' : 'Kosong', style: TextStyle(color: occupied ? Colors.orange.shade800 : _teal, fontWeight: FontWeight.w600)),
          ])));
        }),
      ]);
    }),
  );
}

class MenuView extends StatelessWidget {
  final FirefaLocalStore store;
  const MenuView({super.key, required this.store});

  Future<void> _edit(BuildContext context, {MenuProduct? product}) async {
    final name = TextEditingController(text: product?.name ?? '');
    final category = TextEditingController(text: product?.category ?? 'Food');
    final price = TextEditingController(text: product?.price.toString() ?? '');
    final stock = TextEditingController(text: product?.stock.toString() ?? '0');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product == null ? 'Tambah Menu' : 'Ubah Menu'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nama menu'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null),
              const SizedBox(height: 10),
              TextFormField(controller: category, decoration: const InputDecoration(labelText: 'Kategori'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null),
              const SizedBox(height: 10),
              TextFormField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga (Rupiah)'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 1 ? 'Masukkan harga valid' : null),
              const SizedBox(height: 10),
              if (product == null)
                TextFormField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stok awal'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? 'Masukkan stok valid' : null)
              else
                Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text('Stok saat ini: ${product.stock} unit. Perubahan stok dilakukan dari Inventory.', style: const TextStyle(color: _muted, fontSize: 12)))),
            ])),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
          }, child: const Text('Simpan')),
        ],
      ),
    );
    if (result == true) {
      try {
        await store.saveMenuProduct(
          id: product?.id,
          name: name.text,
          category: category.text,
          price: int.parse(price.text),
          openingStock: product?.stock ?? int.parse(stock.text),
        );
      } catch (error) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Menu gagal disimpan: $error')));
      }
    }
    name.dispose();
    category.dispose();
    price.dispose();
    stock.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Menu Management',
    subtitle: 'Tambah dan ubah menu yang digunakan langsung oleh POS.',
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _edit(context), icon: const Icon(Icons.add), label: const Text('Tambah Menu'))),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        for (final product in store.products) ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.restaurant_menu, color: _teal)),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${product.category} • Stok ${product.stock}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_rupiah(product.price), style: const TextStyle(color: _teal, fontWeight: FontWeight.w700)),
            IconButton(tooltip: 'Ubah menu', onPressed: () => _edit(context, product: product), icon: const Icon(Icons.edit_outlined)),
          ]),
        ),
      ])),
    ]),
  );
}

class PrinterView extends StatelessWidget {
  final FirefaLocalStore store;
  const PrinterView({super.key, required this.store});

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Printer Management',
    subtitle: 'Atur target printer kasir, kitchen, dan bar. Tes cetak di sini masih berupa simulasi.',
    child: Column(children: [
      for (final role in store.printerTargets.keys) Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _PrinterConfigForm(store: store, role: role),
        ),
      ),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.info_outline, color: _muted),
        SizedBox(width: 10),
        Expanded(child: Text('Printer fisik belum terhubung. Pengaturan ini menyimpan target lokal dan belum mengirim pekerjaan cetak ke perangkat.')),
      ]))),
    ]),
  );
}

class _PrinterConfigForm extends StatefulWidget {
  final FirefaLocalStore store;
  final String role;
  const _PrinterConfigForm({required this.store, required this.role});

  @override
  State<_PrinterConfigForm> createState() => _PrinterConfigFormState();
}

class _PrinterConfigFormState extends State<_PrinterConfigForm> {
  late final TextEditingController target;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    target = TextEditingController(text: widget.store.printerTargets[widget.role]);
    enabled = widget.store.printerEnabled[widget.role]!;
  }

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Printer ${widget.role}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktifkan konfigurasi'), value: enabled, onChanged: (value) => setState(() => enabled = value)),
    TextField(controller: target, decoration: const InputDecoration(labelText: 'Nama / alamat printer', hintText: 'Contoh: printer-kasir atau 192.168.1.20')),
    const SizedBox(height: 10),
    Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () async {
      try {
        await widget.store.savePrinterSettings(role: widget.role, enabled: enabled, target: target.text);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Konfigurasi printer ${widget.role} tersimpan.')));
      } catch (error) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan printer: $error')));
      }
    }, child: const Text('Simpan Konfigurasi'))),
  ]);
}

class BusinessSettingsView extends StatefulWidget {
  final FirefaLocalStore store;
  const BusinessSettingsView({super.key, required this.store});

  @override
  State<BusinessSettingsView> createState() => _BusinessSettingsViewState();
}

class _BusinessSettingsViewState extends State<BusinessSettingsView> {
  late final TextEditingController name;
  late final TextEditingController footer;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.store.businessName);
    footer = TextEditingController(text: widget.store.receiptFooter);
  }

  @override
  void dispose() {
    name.dispose();
    footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Pengaturan Bisnis',
    subtitle: 'Identitas restoran digunakan pada tampilan struk lokal.',
    child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama restoran')),
      const SizedBox(height: 14),
      TextField(controller: footer, maxLines: 3, decoration: const InputDecoration(labelText: 'Pesan di bagian bawah struk')),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: () async {
        try {
          await widget.store.saveBusinessSettings(name: name.text, footer: footer.text);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan bisnis tersimpan.')));
        } catch (error) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pengaturan gagal disimpan: $error')));
        }
      }, icon: const Icon(Icons.save_outlined), label: const Text('Simpan Pengaturan')),
      const SizedBox(height: 10),
      const Text('Pengaturan ini tersimpan di perangkat lokal. Sinkronisasi cloud belum aktif.', style: TextStyle(color: _muted, fontSize: 12)),
    ]))),
  );
}

class InventoryView extends StatelessWidget {
  final FirefaLocalStore store;
  const InventoryView({super.key, required this.store});

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Inventory',
    subtitle: 'Stok berkurang saat checkout dan kembali saat pesanan dibatalkan.',
    child: Card(child: Column(children: [
      for (final product in store.products) ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.inventory_2_outlined, color: _teal)),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(product.category),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${product.stock} unit', style: TextStyle(color: product.stock <= 5 ? Colors.red : _ink, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Terima 5 unit', onPressed: () async {
            try { await store.receiveStock(product, 5); } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stok gagal disimpan: $error'))); }
          }, icon: const Icon(Icons.add_circle_outline, color: _teal)),
        ]),
      ),
    ])),
  );
}

class ReportsView extends StatelessWidget {
  final FirefaLocalStore store;
  const ReportsView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final completed = store.orders.where((order) => order.status == 'Selesai').toList();
    final cancelled = store.orders.where((order) => order.status == 'Dibatalkan').length;
    final completedSales = completed.fold(0, (sum, order) => sum + order.total);
    return PageFrame(
      title: 'Laporan Penjualan',
      subtitle: 'Ringkasan dihitung dari transaksi lokal yang tersimpan.',
      child: Wrap(spacing: 16, runSpacing: 16, children: [
        _MetricCard(label: 'Total Order', value: '${store.orders.length}', icon: Icons.receipt_long, note: 'Semua status'),
        _MetricCard(label: 'Order Selesai', value: '${completed.length}', icon: Icons.task_alt, note: 'Status selesai'),
        _MetricCard(label: 'Penjualan Selesai', value: _rupiah(completedSales), icon: Icons.payments, note: 'Status selesai'),
        _MetricCard(label: 'Dibatalkan', value: '$cancelled', icon: Icons.cancel_outlined, note: 'Tidak dihitung sebagai penjualan'),
      ]),
    );
  }
}
