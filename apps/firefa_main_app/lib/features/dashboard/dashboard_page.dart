import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import '../modules/pos_page.dart';
import '../modules/orders_page.dart';
import '../modules/tables_page.dart';
import '../modules/menu_page.dart';
import '../modules/inventory_page.dart';
import '../modules/reports_page.dart';
import '../modules/settings_page.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/stat_card.dart';
import 'widgets/revenue_card.dart';
import 'widgets/recent_orders_card.dart';
import 'widgets/top_selling_card.dart';

class DashboardPage extends StatefulWidget {
  final FirefaRole role;

  const DashboardPage({super.key, this.role = FirefaRole.owner});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF64748B);
  static const primary = Color(0xFF008F83);

  final outletStore = FirefaActiveOutletStore.instance;

  late int selectedIndex;
  bool sidebarCollapsed = true;

  static const pageTitles = [
    'Dashboard',
    'Point of Sale',
    'Orders',
    'Tables',
    'Menu Management',
    'Inventory',
    'Reports',
    'Settings',
  ];

  static const pageDescriptions = [
    'Pantau performa operasional bisnis Anda.',
    'Kelola transaksi dan pembayaran pelanggan.',
    'Pantau dan kelola seluruh pesanan.',
    'Atur meja dan aktivitas pelayanan.',
    'Kelola produk, kategori, dan harga menu.',
    'Pantau stok bahan baku dan persediaan.',
    'Analisis penjualan dan performa bisnis.',
    'Kelola preferensi dan konfigurasi bisnis.',
  ];

  static const pagePermissions = [
    FirefaPermission.dashboardView,
    FirefaPermission.posAccess,
    FirefaPermission.ordersView,
    FirefaPermission.tablesManage,
    FirefaPermission.menuManage,
    FirefaPermission.inventoryManage,
    FirefaPermission.reportsView,
    FirefaPermission.settingsManage,
  ];

  @override
  void initState() {
    super.initState();

    outletStore.initializeForRole(widget.role);

    selectedIndex = pagePermissions.indexWhere(
      (permission) => FirefaAccess.can(widget.role, permission),
    );

    outletStore.addListener(_onOutletChanged);
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.role != widget.role) {
      outletStore.initializeForRole(widget.role);

      selectedIndex = pagePermissions.indexWhere(
        (permission) => FirefaAccess.can(widget.role, permission),
      );
    }
  }

  @override
  void dispose() {
    outletStore.removeListener(_onOutletChanged);
    super.dispose();
  }

  void _onOutletChanged() {
    if (mounted) setState(() {});
  }

  void _selectPage(int index) {
    if (index < 0 || index >= pagePermissions.length) return;

    if (!FirefaAccess.can(widget.role, pagePermissions[index])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak memiliki izin mengakses modul ini.'),
        ),
      );
      return;
    }

    setState(() => selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          DashboardSidebar(
            selectedIndex: selectedIndex,
            collapsed: sidebarCollapsed,
            role: widget.role,
            onToggle: () {
              setState(() => sidebarCollapsed = !sidebarCollapsed);
            },
            onSelected: _selectPage,
          ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey(selectedIndex),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopbar(),
                      const SizedBox(height: 28),
                      if (selectedIndex >= 0) ...[
                        _buildPageHeading(),
                        const SizedBox(height: 24),
                        if (selectedIndex == 0)
                          _buildDashboardContent()
                        else
                          _buildModuleContent(),
                      ] else
                        const Center(
                          child: Text('Tidak ada modul yang dapat diakses.'),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;

        final greeting = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, ${widget.role.label}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Kelola bisnis F&B Anda bersama FIREFA',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        );

        final actions = Row(
          children: [
            Expanded(child: _buildOutletSelector()),
            const SizedBox(width: 12),
            Tooltip(
              message: widget.role.label,
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFE0F2F1),
                child: Icon(Icons.person_outline, color: primary),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [greeting, const SizedBox(height: 18), actions],
          );
        }

        return Row(
          children: [
            Expanded(child: greeting),
            const SizedBox(width: 16),
            SizedBox(width: 235, child: actions),
          ],
        );
      },
    );
  }

  Widget _buildOutletSelector() {
    final available = outletStore.accessibleOutlets;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: outletStore.selectedOutletId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: available.map((outlet) {
            return DropdownMenuItem<String>(
              value: outlet.id,
              child: Text(
                outlet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            final success = outletStore.selectOutlet(value);

            if (!success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Akses outlet tidak diizinkan.')),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildPageHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedIndex == 0 ? 'Dashboard Overview' : pageTitles[selectedIndex],
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pageDescriptions[selectedIndex],
          style: const TextStyle(color: muted, fontSize: 14),
        ),
        if (selectedIndex == 1 || selectedIndex == 2) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: primary),
              const SizedBox(width: 6),
              Text(
                'Active Outlet: ${outletStore.selectedOutletName}',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStats(),
        const SizedBox(height: 24),
        const RevenueCard(),
        const SizedBox(height: 24),
        _buildOperationalOverview(),
      ],
    );
  }

  Widget _buildStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns = 1;

        if (width >= 1050) {
          columns = 4;
        } else if (width >= 580) {
          columns = 2;
        }

        final cardWidth = (width - (columns - 1) * 16) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              height: 180,
              child: const StatCard(
                title: "Today's Sales",
                value: 'Rp 8.500.000',
                icon: Icons.payments_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 180,
              child: const StatCard(
                title: 'Orders',
                value: '245',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 180,
              child: const StatCard(
                title: 'Active Tables',
                value: '18',
                icon: Icons.table_bar_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 180,
              child: const StatCard(
                title: 'Low Stock',
                value: '5',
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationalOverview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return const Column(
            children: [
              RecentOrdersCard(),
              SizedBox(height: 20),
              TopSellingCard(),
            ],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: RecentOrdersCard()),
            SizedBox(width: 20),
            Expanded(flex: 4, child: TopSellingCard()),
          ],
        );
      },
    );
  }

  Widget _buildModuleContent() {
    switch (selectedIndex) {
      case 1:
        return const PosPage();
      case 2:
        return const OrdersPage();
      case 3:
        return const TablesPage();
      case 4:
        return const MenuPage();
      case 5:
        return const InventoryPage();
      case 6:
        return const ReportsPage();
      case 7:
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }
}
