import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
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
  late int selectedIndex;
  bool sidebarCollapsed = true;
  String selectedOutlet = 'Semua Outlet';

  final List<String> outlets = const [
    'Semua Outlet',
    'Outlet Utama',
    'Outlet 2',
  ];

  static const List<String> pageTitles = [
    'Dashboard',
    'Point of Sale',
    'Orders',
    'Tables',
    'Menu Management',
    'Inventory',
    'Reports',
    'Settings',
  ];

  static const List<String> pageDescriptions = [
    'Pantau performa operasional bisnis Anda.',
    'Kelola transaksi dan pembayaran pelanggan.',
    'Pantau dan kelola seluruh pesanan.',
    'Atur meja dan aktivitas pelayanan.',
    'Kelola produk, kategori, dan harga menu.',
    'Pantau stok bahan baku dan persediaan.',
    'Analisis penjualan dan performa bisnis.',
    'Kelola preferensi dan konfigurasi bisnis.',
  ];

  static const List<IconData> pageIcons = [
    Icons.dashboard_outlined,
    Icons.point_of_sale_outlined,
    Icons.receipt_long_outlined,
    Icons.table_bar_outlined,
    Icons.restaurant_menu_outlined,
    Icons.inventory_2_outlined,
    Icons.analytics_outlined,
    Icons.settings_outlined,
  ];

  static const List<FirefaPermission> pagePermissions = [
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

    selectedIndex = pagePermissions.indexWhere(
      (permission) => FirefaAccess.can(widget.role, permission),
    );
  }

  void _selectPage(int index) {
    if (index < 0 || index >= pagePermissions.length) {
      return;
    }

    if (!FirefaAccess.can(widget.role, pagePermissions[index])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak memiliki izin mengakses modul ini.'),
        ),
      );
      return;
    }

    setState(() {
      selectedIndex = index;
    });
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
              setState(() {
                sidebarCollapsed = !sidebarCollapsed;
              });
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
                color: Color(0xFF172B4D),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Kelola bisnis F&B Anda bersama FIREFA',
              style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade500),
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
                child: Icon(Icons.person_outline, color: Color(0xFF00897B)),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              greeting,
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: actions),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedOutlet,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: outlets.map((outlet) {
            return DropdownMenuItem<String>(
              value: outlet,
              child: Text(
                outlet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedOutlet = value;
              });
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
            color: Color(0xFF172B4D),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pageDescriptions[selectedIndex],
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
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
                value: "Rp 8.500.000",
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
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 45),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              pageIcons[selectedIndex],
              size: 42,
              color: const Color(0xFF009688),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            pageTitles[selectedIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B4D),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              pageDescriptions[selectedIndex],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Module UI • Coming Soon',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 45),
        ],
      ),
    );
  }
}
