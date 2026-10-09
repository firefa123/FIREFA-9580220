import 'package:flutter/material.dart';

class OwnerSidebarItem {
  final String label;
  final IconData icon;

  const OwnerSidebarItem({
    required this.label,
    required this.icon,
  });
}

const ownerSidebarItems = [
  OwnerSidebarItem(label: 'Dashboard', icon: Icons.dashboard),
  OwnerSidebarItem(label: 'Order', icon: Icons.receipt_long),
  OwnerSidebarItem(label: 'Menu', icon: Icons.restaurant_menu),
  OwnerSidebarItem(label: 'Staff', icon: Icons.people),
  OwnerSidebarItem(label: 'Outlet', icon: Icons.store),
  OwnerSidebarItem(label: 'Analytics', icon: Icons.analytics),
  OwnerSidebarItem(label: 'Settings', icon: Icons.settings),
  OwnerSidebarItem(label: 'Profile', icon: Icons.person),
];
