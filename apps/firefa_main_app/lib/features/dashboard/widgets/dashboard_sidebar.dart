import 'package:flutter/material.dart';

import '../../../core/auth/role_permissions.dart';

class DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;
  final VoidCallback onToggle;
  final FirefaRole role;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.collapsed,
    required this.onToggle,
    this.role = FirefaRole.owner,
  });

  static const List<(String, IconData, FirefaPermission)> menus = [
    ('Dashboard', Icons.dashboard_outlined, FirefaPermission.dashboardView),
    ('POS', Icons.point_of_sale_outlined, FirefaPermission.posAccess),
    ('Orders', Icons.receipt_long_outlined, FirefaPermission.ordersView),
    ('Tables', Icons.table_bar_outlined, FirefaPermission.tablesManage),
    ('Menu', Icons.restaurant_menu_outlined, FirefaPermission.menuManage),
    ('Inventory', Icons.inventory_2_outlined, FirefaPermission.inventoryManage),
    ('Reports', Icons.analytics_outlined, FirefaPermission.reportsView),
    ('Settings', Icons.settings_outlined, FirefaPermission.settingsManage),
  ];

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = collapsed ? 72.0 : 230.0;

    final visibleMenus = [
      for (int i = 0; i < menus.length; i++)
        if (FirefaAccess.can(role, menus[i].$3)) i,
    ];

    return SizedBox(
      width: sidebarWidth,
      height: double.infinity,
      child: Material(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            SizedBox(
              height: 72,
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                    onPressed: onToggle,
                    icon: const Icon(Icons.menu),
                  ),
                  if (!collapsed)
                    const Flexible(
                      child: Text(
                        'FIREFA',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: visibleMenus.length,
                itemBuilder: (context, index) {
                  final originalIndex = visibleMenus[index];
                  final menu = menus[originalIndex];
                  final isActive = selectedIndex == originalIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Tooltip(
                      message: collapsed ? menu.$1 : '',
                      child: Material(
                        color: isActive
                            ? const Color(0xFFE0F2F1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelected(originalIndex),
                          child: SizedBox(
                            height: 48,
                            child: collapsed
                                ? Center(
                                    child: Icon(
                                      menu.$2,
                                      size: 23,
                                      color: isActive
                                          ? Colors.teal.shade700
                                          : Colors.blueGrey,
                                    ),
                                  )
                                : Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      Icon(
                                        menu.$2,
                                        size: 23,
                                        color: isActive
                                            ? Colors.teal.shade700
                                            : Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          menu.$1,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: isActive
                                                ? Colors.teal.shade800
                                                : Colors.blueGrey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: collapsed
                  ? const Center(
                      child: Tooltip(
                        message: 'Online (Demo)',
                        child: Icon(
                          Icons.cloud_done_outlined,
                          color: Colors.teal,
                        ),
                      ),
                    )
                  : const Row(
                      children: [
                        Icon(Icons.cloud_done_outlined, color: Colors.teal),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Online (Demo)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
