import 'package:flutter/material.dart';

import '../auth/role_permissions.dart';
import 'app_routes.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/modules/pos_page.dart';
import '../../features/modules/orders_page.dart';
import '../../features/modules/tables_page.dart';
import '../../features/modules/menu_page.dart';
import '../../features/modules/inventory_page.dart';
import '../../features/modules/reports_page.dart';
import '../../features/modules/settings_page.dart';
import '../../features/modules/supplier_page.dart';
import '../../features/modules/purchase_order_page.dart';

class FirefaMainNavigation extends StatefulWidget {
  final FirefaRole role;

  const FirefaMainNavigation({super.key, required this.role});

  @override
  State<FirefaMainNavigation> createState() => _FirefaMainNavigationState();
}

class _FirefaMainNavigationState extends State<FirefaMainNavigation> {
  int selectedIndex = 0;

  Widget _pageForModule(String id) {
    switch (id) {
      case 'dashboard': return DashboardPage(role: widget.role);
      case 'pos': return const PosPage();
      case 'orders': return const OrdersPage();
      case 'tables': return const TablesPage();
      case 'menu': return const MenuPage();
      case 'inventory': return const InventoryPage();
      case 'reports': return const ReportsPage();
      case 'settings': return const SettingsPage();
      case 'suppliers': return const SupplierPage();
      case 'purchasing': return const PurchaseOrderPage();
      default: return const Center(child: Text('Module belum tersedia'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final modules = FirefaNavigation.accessibleModules(widget.role);
    if (modules.isEmpty) {
      return const Scaffold(body: Center(child: Text('Tidak ada modul tersedia')));
    }

    final safeIndex = selectedIndex >= modules.length ? 0 : selectedIndex;
    final selectedModule = modules[safeIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedModule.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(widget.role.name.toUpperCase())),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Text('FIREFA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              for (var i = 0; i < modules.length; i++)
                ListTile(
                  leading: Icon(modules[i].icon),
                  title: Text(modules[i].title),
                  selected: i == safeIndex,
                  onTap: () {
                    setState(() => selectedIndex = i);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
      body: _pageForModule(selectedModule.id),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: [
          for (final module in modules)
            NavigationDestination(
              icon: Icon(module.icon),
              label: module.title,
            ),
        ],
      ),
    );
  }
}
