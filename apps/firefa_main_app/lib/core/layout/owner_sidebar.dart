import 'package:flutter/material.dart';

class OwnerSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const OwnerSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const items = [
    ('Dashboard', Icons.dashboard),
    ('Order', Icons.receipt_long),
    ('Menu', Icons.restaurant_menu),
    ('Staff', Icons.people),
    ('Outlet', Icons.store),
    ('Analytics', Icons.analytics),
    ('Settings', Icons.settings),
    ('Profile', Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.$2),
            label: Text(item.$1),
          ),
      ],
    );
  }
}
