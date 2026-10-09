import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/outlet/active_outlet_store.dart';
import 'menu_store.dart';
import 'order_models.dart';
import 'order_store.dart';
import 'pos_payment_dialog.dart';
import 'persistent_cart_store.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  static const primary = Color(0xFF008F83);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  final outletStore = FirefaActiveOutletStore.instance;
  final searchController = TextEditingController();

  // Keranjang dipisahkan per outlet agar tidak tercampur.
  final Map<String, List<_CartItem>> carts = {};
  final Map<String, _OrderSettings> settings = {};
  final persistentStore = FirefaPersistentCartStore.instance;
  final menuStore = FirefaMenuStore.instance;
  late final Future<void> menuReady;

  void _restoreOutlet(String id) {
    if (carts.containsKey(id)) return;
    final saved = persistentStore.getCart(id);
    carts[id] = saved.items.map((item) {
      final product = _resolveSavedProduct(id, item);
      if (product == null) return null;
      return _CartItem(
        product: product,
        size: item.size,
        extras: List<String>.from(item.extras),
        note: item.note,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      );
    }).whereType<_CartItem>().toList();
    settings[id] = _OrderSettings()
      ..orderType = saved.orderType
      ..table = saved.table
      ..discountType = saved.discountType
      ..discountInput = saved.discountInput
      ..taxRate = saved.taxRate
      ..serviceRate = saved.serviceRate;
  }

  void _saveCart() {
    final id = outletId;
    persistentStore.saveCart(
      id,
      FirefaCartData(
        items: cart.map((item) => FirefaCartItemData(
          productId: item.product.id,
          productName: item.product.name,
          size: item.size,
          extras: List<String>.from(item.extras),
          note: item.note,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
        )).toList(),
        orderType: config.orderType,
        table: config.table,
        discountType: config.discountType,
        discountInput: config.discountInput,
        taxRate: config.taxRate,
        serviceRate: config.serviceRate,
      ),
    );
  }

  String category = 'All';

  String get outletId => outletStore.selectedOutletId;
  String get outletName => outletStore.selectedOutletName;

  List<_CartItem> get cart {
    _restoreOutlet(outletId);
    return carts[outletId]!;
  }

  _OrderSettings get config {
    _restoreOutlet(outletId);
    return settings[outletId]!;
  }

  static const categories = [
    'All',
    'Coffee',
    'Non Coffee',
    'Food',
    'Snacks',
    'Dessert',
    'Other',
  ];

  static const products = <_Product>[
    _Product(
      'P01',
      'Cappuccino',
      'Coffee',
      28000,
      Icons.coffee,
      Color(0xFFF5E8DC),
    ),
    _Product(
      'P02',
      'Cafe Latte',
      'Coffee',
      30000,
      Icons.local_cafe,
      Color(0xFFEFE2D3),
    ),
    _Product(
      'P03',
      'Americano',
      'Coffee',
      24000,
      Icons.coffee_outlined,
      Color(0xFFE6E1DA),
    ),
    _Product(
      'P04',
      'Matcha Latte',
      'Non Coffee',
      32000,
      Icons.emoji_food_beverage,
      Color(0xFFE6F0DD),
    ),
    _Product(
      'P05',
      'Chocolate Ice',
      'Non Coffee',
      29000,
      Icons.local_drink_outlined,
      Color(0xFFF3E3DE),
    ),
    _Product(
      'P06',
      'Lemon Tea',
      'Non Coffee',
      22000,
      Icons.local_bar_outlined,
      Color(0xFFF7EFCB),
    ),
    _Product(
      'P07',
      'Nasi Goreng',
      'Food',
      38000,
      Icons.rice_bowl_outlined,
      Color(0xFFF9E9D6),
    ),
    _Product(
      'P08',
      'Chicken Katsu',
      'Food',
      42000,
      Icons.lunch_dining_outlined,
      Color(0xFFF5E4D3),
    ),
    _Product(
      'P09',
      'Beef Burger',
      'Food',
      45000,
      Icons.lunch_dining,
      Color(0xFFF7E7D2),
    ),
    _Product(
      'P10',
      'French Fries',
      'Snacks',
      25000,
      Icons.fastfood_outlined,
      Color(0xFFFFECCC),
    ),
    _Product(
      'P11',
      'Chicken Wings',
      'Snacks',
      35000,
      Icons.tapas_outlined,
      Color(0xFFF4E4D7),
    ),
    _Product(
      'P12',
      'Cheesecake',
      'Dessert',
      34000,
      Icons.cake_outlined,
      Color(0xFFF8E7EC),
    ),
  ];

  @override
  void initState() {
    super.initState();
    menuReady = menuStore.initialize();
    menuStore.addListener(_onOutletChanged);
    outletStore.addListener(_onOutletChanged);
  }

  void _onOutletChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    outletStore.removeListener(_onOutletChanged);
    menuStore.removeListener(_onOutletChanged);
    searchController.dispose();
    super.dispose();
  }

  _Product _fromMenu(FirefaMenuItem item) => _Product(
    item.id, item.name, item.category, item.price,
    Icons.restaurant_menu, const Color(0xFFE0F2F1),
  );

  _Product? _resolveSavedProduct(String id, FirefaCartItemData saved) {
    final demo = products.where((p) => p.id == saved.productId).firstOrNull;
    if (demo != null) {
      return _Product(demo.id, saved.productName ?? demo.name,
          demo.category, demo.price, demo.icon, demo.color);
    }
    final matches = menuStore.forOutlet(id)
        .where((item) => item.id == saved.productId);
    final menu = matches.firstOrNull;
    if (menu != null) {
      final current = _fromMenu(menu);
      return _Product(current.id, saved.productName ?? current.name,
          current.category, current.price, current.icon, current.color);
    }
    if (saved.productName != null) {
      return _Product(saved.productId, saved.productName!, 'Other',
          saved.unitPrice, Icons.restaurant_menu, const Color(0xFFE0F2F1));
    }
    return _Product(saved.productId, 'Produk lama (${saved.productId})',
        'Other', saved.unitPrice, Icons.restaurant_menu,
        const Color(0xFFE0F2F1));
  }

  List<_Product> get catalogProducts {
    final items = menuStore.forOutlet(outletId);
    if (items.isEmpty) return products;
    return items.where((item) => item.isActive).map(_fromMenu).toList();
  }

  List<_Product> get visibleProducts {
    final query = searchController.text.toLowerCase().trim();
    return catalogProducts.where((product) {
      return (category == 'All' || category == product.category) &&
          product.name.toLowerCase().contains(query);
    }).toList();
  }

  int get itemCount => cart.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => cart.fold(0, (sum, item) => sum + item.total);

  int get discountAmount {
    if (config.discountType == 'Percent') {
      return (subtotal * config.discountInput.clamp(0, 100) / 100).round();
    }
    return config.discountInput.clamp(0, subtotal);
  }

  int get discountedSubtotal => subtotal - discountAmount;

  int get taxAmount => (discountedSubtotal * config.taxRate / 100).round();

  int get serviceAmount =>
      (discountedSubtotal * config.serviceRate / 100).round();

  int get grandTotal => discountedSubtotal + taxAmount + serviceAmount;

  String rupiah(int value) =>
      'Rp ${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

  void addItem(_CartItem item, {_CartItem? editing}) {
    setState(() {
      if (editing != null) cart.remove(editing);

      final index = cart.indexWhere(
        (existing) => existing.configurationKey == item.configurationKey &&
            existing.unitPrice == item.unitPrice &&
            existing.product.name == item.product.name,
      );

      if (index >= 0) {
        cart[index].quantity += item.quantity;
      } else {
        cart.add(item);
      }
    });
    _saveCart();
  }

  void changeQuantity(_CartItem item, int change) {
    setState(() {
      item.quantity += change;
      if (item.quantity <= 0) cart.remove(item);
    });
    _saveCart();
  }

  Future<void> configureProduct(_Product product, {_CartItem? editing}) async {
    final sourceOutlet = outletId;
    if (editing == null && !catalogProducts.any((p) => p.id == product.id)) {
      return;
    }
    final isDrink =
        product.category == 'Coffee' || product.category == 'Non Coffee';

    final sizes = isDrink
        ? const {'Regular': 0, 'Large': 6000}
        : const {'Regular': 0};

    final extras = isDrink
        ? const {'Extra Shot': 5000, 'Oat Milk': 7000, 'Whipped Cream': 4000}
        : const {'Extra Cheese': 6000, 'Extra Egg': 5000, 'Extra Sauce': 3000};

    String size = editing?.size ?? 'Regular';
    final selectedExtras = <String>{...?editing?.extras};
    int quantity = editing?.quantity ?? 1;

    final noteController = TextEditingController(text: editing?.note ?? '');
    final snapshotBase = editing == null ? product.price :
        editing.unitPrice - (sizes[editing.size] ?? 0) -
        editing.extras.fold<int>(0, (sum, name) => sum + (extras[name] ?? 0));

    final result = await showDialog<_CartItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final extrasPrice = selectedExtras.fold<int>(
            0,
            (sum, name) => sum + (extras[name] ?? 0),
          );

          final unitPrice = snapshotBase + (sizes[size] ?? 0) + extrasPrice;

          return AlertDialog(
            title: Text(editing == null ? 'Customize Product' : 'Edit Item'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(rupiah(product.price)),
                    const SizedBox(height: 18),
                    const Text(
                      'Size / Portion',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final entry in sizes.entries)
                          ChoiceChip(
                            label: Text(
                              entry.value == 0
                                  ? entry.key
                                  : '${entry.key} (+${rupiah(entry.value)})',
                            ),
                            selected: size == entry.key,
                            showCheckmark: false,
                            selectedColor: const Color(0xFFE0F2F1),
                            onSelected: (_) => update(() => size = entry.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add-ons',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final entry in extras.entries)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: primary,
                        title: Text(entry.key),
                        subtitle: Text('+ ${rupiah(entry.value)}'),
                        value: selectedExtras.contains(entry.key),
                        onChanged: (checked) => update(() {
                          if (checked == true) {
                            selectedExtras.add(entry.key);
                          } else {
                            selectedExtras.remove(entry.key);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Special Instructions',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Quantity')),
                        IconButton(
                          onPressed: quantity > 1
                              ? () => update(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$quantity'),
                        IconButton(
                          onPressed: () => update(() => quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(child: Text('Item Total')),
                        Text(
                          rupiah(unitPrice * quantity),
                          style: const TextStyle(
                            color: primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: primary),
                onPressed: () => Navigator.pop(
                  context,
                  _CartItem(
                    product: product,
                    size: size,
                    extras: selectedExtras.toList()..sort(),
                    note: noteController.text.trim(),
                    unitPrice: unitPrice,
                    quantity: quantity,
                  ),
                ),
                child: Text(editing == null ? 'Add to Order' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    // Controller digunakan hanya selama dialog.
    if (!mounted || result == null) return;

    if (sourceOutlet != outletId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outlet berubah. Silakan pilih produk kembali.'),
        ),
      );
      return;
    }

    if (editing == null) {
      final latest = catalogProducts.where((p) => p.id == product.id).firstOrNull;
      if (latest == null || latest.price != product.price ||
          latest.name != product.name || latest.category != product.category) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Katalog berubah. Pilih produk kembali untuk harga terbaru.'),
        ));
        return;
      }
    } else if (!cart.contains(editing)) {
      return;
    }
    addItem(result, editing: editing);
  }

  Future<void> openChargesDialog() async {
    final sourceOutlet = outletId;
    String draftType = config.discountType;
    int draftDiscount = config.discountInput;
    int draftTax = config.taxRate;
    int draftService = config.serviceRate;

    final controller = TextEditingController(text: '$draftDiscount');

    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Discount & Charges'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Nominal', label: Text('Nominal')),
                      ButtonSegment(value: 'Percent', label: Text('Percent')),
                    ],
                    selected: {draftType},
                    onSelectionChanged: (value) => update(() {
                      draftType = value.first;
                      draftDiscount = 0;
                      controller.text = '0';
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: InputDecoration(
                      labelText: draftType == 'Percent'
                          ? 'Discount (%)'
                          : 'Discount (Rp)',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => update(() {
                      final amount = int.tryParse(value) ?? 0;
                      draftDiscount = draftType == 'Percent'
                          ? amount.clamp(0, 100)
                          : amount.clamp(0, 999999999999);
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tax Rate (Demo)'),
                  DropdownButtonFormField<int>(
                    initialValue: draftTax,
                    items: const [0, 5, 10, 11, 12]
                        .map(
                          (rate) => DropdownMenuItem(
                            value: rate,
                            child: Text('$rate%'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => update(() => draftTax = value ?? 0),
                  ),
                  const SizedBox(height: 16),
                  const Text('Service Charge (Demo)'),
                  DropdownButtonFormField<int>(
                    initialValue: draftService,
                    items: const [0, 5, 7, 10]
                        .map(
                          (rate) => DropdownMenuItem(
                            value: rate,
                            child: Text('$rate%'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        update(() => draftService = value ?? 0),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (apply != true || !mounted || sourceOutlet != outletId) {
      return;
    }

    setState(() {
      config.discountType = draftType;
      config.discountInput = draftDiscount;
      config.taxRate = draftTax;
      config.serviceRate = draftService;
    });
    _saveCart();
  }

  bool _checkoutBusy = false;

  Future<void> checkout() async {
    if (_checkoutBusy || cart.isEmpty || !outletStore.canAccessOutlet(outletId)) {
      return;
    }
    final sourceOutlet = outletId;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Checkout'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$outletName • ${config.orderType} • $itemCount item',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Tagihan',
                        style: TextStyle(fontSize: 12, color: muted)),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rupiah(grandTotal),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Bayar Nanti menyimpan pesanan sebagai Unpaid. '
                'Bayar Sekarang membuka simulasi pembayaran.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'later'),
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: const Text('Bayar Nanti'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'now'),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Bayar Sekarang'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || sourceOutlet != outletId) return;

    PosPaymentResult? payment;
    if (choice == 'now') {
      if (grandTotal <= 0) return;
      payment = await showDialog<PosPaymentResult>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PosPaymentDialog(
          total: grandTotal,
          orderType: config.orderType,
          table: config.orderType == 'Dine In' ? config.table : null,
          itemCount: itemCount,
        ),
      );
      if (!mounted || payment == null || sourceOutlet != outletId) return;
    }

    if (_checkoutBusy || cart.isEmpty || !outletStore.canAccessOutlet(sourceOutlet)) {
      return;
    }
    setState(() => _checkoutBusy = true);
    try {
      final store = FirefaOrderStore.instance;
      final order = store.createOrder(
        outletId: sourceOutlet,
        orderType: config.orderType,
        tableId: config.orderType == 'Dine In' ? config.table : null,
        items: cart.map((item) => FirefaOrderItem(
          productName: item.product.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          details: item.details,
        )).toList(),
        subtotal: subtotal,
        discount: discountAmount,
        tax: taxAmount,
        service: serviceAmount,
        total: grandTotal,
      );
      if (payment != null) {
        if (!store.markPaid(sourceOutlet, order.id)) {
          throw StateError('Status pembayaran tidak dapat diperbarui.');
        }
      }
      await store.waitForPendingSave();
      if (!mounted) return;
      setState(() {
        cart.clear();
        config.resetCharges();
      });
      _saveCart();
      await persistentStore.waitForPendingSave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          '${order.id} tersimpan — ${payment == null ? 'Unpaid' : 'Paid (simulasi)'}.',
        )),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout gagal: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkoutBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: menuReady,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Gagal memuat katalog menu lokal. Keranjang lama tidak diubah.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildReadyPos(context);
      },
    );
  }

  Widget _buildReadyPos(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Wide desktops keep the cart visible beside the catalog.
        // Tablets and phones stack the cart below the products.
        if (width >= 950) {
          final cartWidth = width >= 1200 ? 370.0 : 330.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: buildCatalog()),
              const SizedBox(width: 20),
              SizedBox(width: cartWidth, child: buildCart()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildCatalog(),
            const SizedBox(height: 20),
            buildCart(),
          ],
        );
      },
    );
  }

  Widget buildCatalog() {
    return FutureBuilder<void>(
      future: menuReady,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Katalog menu lokal gagal dimuat. Data lama tidak diubah.');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildReadyCatalog();
      },
    );
  }

  Widget _buildReadyCatalog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Product Catalog',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ),
            Text(
              '${visibleProducts.length} Products',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Cari nama produk...',
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Hapus pencarian',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                  ),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: border),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final value in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(value),
                    selected: category == value,
                    showCheckmark: false,
                    selectedColor: const Color(0xFFE0F2F1),
                    onSelected: (_) => setState(() => category = value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 800
                ? 4
                : width >= 540
                ? 3
                : width >= 350
                ? 2
                : 1;

            if (visibleProducts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_outlined, size: 36, color: muted),
                      SizedBox(height: 10),
                      Text('Produk tidak ditemukan', style: TextStyle(color: ink)),
                      SizedBox(height: 4),
                      Text('Coba kata kunci atau kategori lain.',
                          style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleProducts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: width < 350 ? 235 : 225,
              ),
              itemBuilder: (context, index) {
                final product = visibleProducts[index];
                final count = cart
                    .where((item) => item.product.id == product.id)
                    .fold<int>(0, (sum, item) => sum + item.quantity);

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => configureProduct(product),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: product.color,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(15),
                                    ),
                                  ),
                                  child: Icon(
                                    product.icon,
                                    size: 54,
                                    color: ink,
                                  ),
                                ),
                                if (count > 0)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: primary,
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: ink,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.category,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rupiah(product.price),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.add_circle,
                                      color: primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget buildCart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current Order',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
              ),
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => cart.clear());
                    _saveCart();
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          Text(
            '$outletName • New Order',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Text('Tipe pesanan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: orderTypeButton('Dine In')),
              const SizedBox(width: 8),
              Expanded(child: orderTypeButton('Takeaway')),
            ],
          ),
          if (config.orderType == 'Dine In') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: config.table,
              decoration: const InputDecoration(
                labelText: 'Select Table',
                border: OutlineInputBorder(),
              ),
              items: const ['A01', 'A02', 'A03', 'B01']
                  .map(
                    (id) =>
                        DropdownMenuItem(value: id, child: Text('Table $id')),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => config.table = value);
                  _saveCart();
                }
              },
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          if (cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 46, color: border),
                    SizedBox(height: 12),
                    Text('Your cart is empty', style: TextStyle(color: muted)),
                  ],
                ),
              ),
            )
          else
            for (final item in cart) cartItemWidget(item),
          const Divider(),
          const SizedBox(height: 12),
          summaryRow('Items', '$itemCount'),
          summaryRow('Subtotal', rupiah(subtotal)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: openChargesDialog,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Discount & Charges'),
            style: OutlinedButton.styleFrom(foregroundColor: primary),
          ),
          const SizedBox(height: 10),
          summaryRow('Discount', '- ${rupiah(discountAmount)}'),
          summaryRow('Tax (${config.taxRate}%)', rupiah(taxAmount)),
          summaryRow('Service (${config.serviceRate}%)', rupiah(serviceAmount)),
          const Divider(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Grand Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: ink,
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    rupiah(grandTotal),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: cart.isEmpty || _checkoutBusy ? null : checkout,
              icon: const Icon(Icons.shopping_cart_checkout, size: 18),
              label: const Text('Checkout'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Local demo • No real payment',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget orderTypeButton(String value) {
    final selected = config.orderType == value;

    return OutlinedButton(
      onPressed: () {
        setState(() => config.orderType = value);
        _saveCart();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? primary : muted,
        backgroundColor: selected ? const Color(0xFFE0F2F1) : Colors.white,
        side: BorderSide(color: selected ? primary : border),
      ),
      child: Text(value, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget cartItemWidget(_CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.product.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.product.icon, color: ink, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ink,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.details,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  rupiah(item.total),
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => changeQuantity(item, -1),
                      icon: const Icon(Icons.remove_circle_outline, size: 19),
                    ),
                    Text('${item.quantity}'),
                    IconButton(
                      onPressed: () => changeQuantity(item, 1),
                      icon: const Icon(Icons.add_circle_outline, size: 19),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () =>
                          configureProduct(item.product, editing: item),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () {
                        setState(() => cart.remove(item));
                        _saveCart();
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSettings {
  String orderType = 'Dine In';
  String table = 'A01';
  String discountType = 'Nominal';
  int discountInput = 0;
  int taxRate = 0;
  int serviceRate = 0;

  void resetCharges() {
    discountType = 'Nominal';
    discountInput = 0;
    taxRate = 0;
    serviceRate = 0;
  }
}

class _Product {
  final String id;
  final String name;
  final String category;
  final int price;
  final IconData icon;
  final Color color;

  const _Product(
    this.id,
    this.name,
    this.category,
    this.price,
    this.icon,
    this.color,
  );
}

class _CartItem {
  final _Product product;
  final String size;
  final List<String> extras;
  final String note;
  final int unitPrice;
  int quantity;

  _CartItem({
    required this.product,
    required this.size,
    required this.extras,
    required this.note,
    required this.unitPrice,
    required this.quantity,
  });

  int get total => unitPrice * quantity;

  String get details =>
      [size, ...extras, if (note.isNotEmpty) 'Note: $note'].join(' • ');

  String get configurationKey => [
    product.id,
    size,
    ([...extras]..sort()).join('|'),
    note,
  ].join('::');
}
