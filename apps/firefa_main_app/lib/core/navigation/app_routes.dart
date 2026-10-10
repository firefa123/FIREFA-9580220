import 'package:flutter/material.dart';

import '../auth/role_permissions.dart';

class FirefaModule {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final FirefaPermission permission;

  const FirefaModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.permission,
  });
}

class FirefaNavigation {
  const FirefaNavigation._();

  static const List<FirefaModule> modules = [
    FirefaModule(
      id: 'dashboard',
      title: 'Dashboard',
      description: 'Pantau performa operasional bisnis Anda.',
      icon: Icons.dashboard_outlined,
      permission: FirefaPermission.dashboardView,
    ),
    FirefaModule(
      id: 'pos',
      title: 'POS',
      description: 'Kelola transaksi dan pembayaran pelanggan.',
      icon: Icons.point_of_sale_outlined,
      permission: FirefaPermission.posAccess,
    ),
    FirefaModule(
      id: 'orders',
      title: 'Orders',
      description: 'Pantau dan kelola seluruh pesanan.',
      icon: Icons.receipt_long_outlined,
      permission: FirefaPermission.ordersView,
    ),
    FirefaModule(
      id: 'tables',
      title: 'Tables',
      description: 'Atur meja dan aktivitas pelayanan.',
      icon: Icons.table_bar_outlined,
      permission: FirefaPermission.tablesManage,
    ),
    FirefaModule(
      id: 'menu',
      title: 'Menu',
      description: 'Kelola produk, kategori, dan harga menu.',
      icon: Icons.restaurant_menu_outlined,
      permission: FirefaPermission.menuManage,
    ),
    FirefaModule(
      id: 'inventory',
      title: 'Inventory',
      description: 'Pantau stok bahan baku dan persediaan.',
      icon: Icons.inventory_2_outlined,
      permission: FirefaPermission.inventoryManage,
    ),
    FirefaModule(
      id: 'reports',
      title: 'Reports',
      description: 'Analisis penjualan dan performa bisnis.',
      icon: Icons.analytics_outlined,
      permission: FirefaPermission.reportsView,
    ),
    FirefaModule(
      id: 'settings',
      title: 'Settings',
      description: 'Kelola preferensi dan konfigurasi bisnis.',
      icon: Icons.settings_outlined,
      permission: FirefaPermission.settingsManage,
    ),
    FirefaModule(
      id: 'suppliers',
      title: 'Suppliers',
      description: 'Kelola daftar pemasok per outlet.',
      icon: Icons.local_shipping_outlined,
      permission: FirefaPermission.inventoryManage,
    ),
    FirefaModule(
      id: 'purchasing',
      title: 'Purchasing',
      description: 'Purchase order dan penerimaan barang.',
      icon: Icons.shopping_cart_checkout_outlined,
      permission: FirefaPermission.inventoryManage,
    ),
  ];

  static List<FirefaModule> accessibleModules(FirefaRole role) {
    return modules
        .where((module) => FirefaAccess.can(role, module.permission))
        .toList();
  }

  static bool canOpen(FirefaRole role, String moduleId) {
    for (final module in modules) {
      if (module.id == moduleId) {
        return FirefaAccess.can(role, module.permission);
      }
    }
    return false;
  }
}
