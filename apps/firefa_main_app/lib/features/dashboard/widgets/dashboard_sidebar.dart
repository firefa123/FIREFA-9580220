import 'package:flutter/material.dart';

class DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;
  final VoidCallback onToggle;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.collapsed,
    required this.onToggle,
  });

  static const List<(String, IconData)> menus = [
    ('Dashboard', Icons.dashboard_outlined),
    ('POS', Icons.point_of_sale_outlined),
    ('Orders', Icons.receipt_long_outlined),
    ('Tables', Icons.table_bar_outlined),
    ('Menu', Icons.restaurant_menu_outlined),
    ('Inventory', Icons.inventory_2_outlined),
    ('Reports', Icons.analytics_outlined),
    ('Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = collapsed ? 72.0 : 230.0;

    return SizedBox(
      width: sidebarWidth,
      height: double.infinity,
      child: Material(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // HEADER
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

            // MENU
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: menus.length,
                itemBuilder: (context, index) {
                  final menu = menus[index];
                  final isActive = selectedIndex == index;

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
                          onTap: () => onSelected(index),
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

            // CLOUD STATUS
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: collapsed
                  ? const Center(
                      child: Tooltip(
                        message: 'Online',
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
                            'Online',
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
