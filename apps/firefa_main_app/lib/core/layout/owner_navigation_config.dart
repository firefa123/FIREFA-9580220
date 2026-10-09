import 'package:flutter/material.dart';

class OwnerNavigationItem {
  final String label;
  final IconData icon;

  const OwnerNavigationItem({
    required this.label,
    required this.icon,
  });
}

class OwnerNavigationConfig {
  static const items = [
    OwnerNavigationItem(label: 'Dashboard', icon: Icons.dashboard),
    OwnerNavigationItem(label: 'Order', icon: Icons.receipt_long),
    OwnerNavigationItem(label: 'Menu', icon: Icons.restaurant_menu),
    OwnerNavigationItem(label: 'Staff', icon: Icons.people),
    OwnerNavigationItem(label: 'Outlet', icon: Icons.store),
    OwnerNavigationItem(label: 'Analytics', icon: Icons.analytics),
    OwnerNavigationItem(label: 'Settings', icon: Icons.settings),
    OwnerNavigationItem(label: 'Profile', icon: Icons.person),
  ];
}
