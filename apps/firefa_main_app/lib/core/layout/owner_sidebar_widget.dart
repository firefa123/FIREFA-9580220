import 'package:flutter/material.dart';
import 'owner_sidebar_navigation.dart';

class OwnerSidebarWidget extends StatelessWidget {
  final ValueChanged<int> onSelected;
  final int selectedIndex;

  const OwnerSidebarWidget({
    super.key,
    required this.onSelected,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      destinations: ownerSidebarItems
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }
}
