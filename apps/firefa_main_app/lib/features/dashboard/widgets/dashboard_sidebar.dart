import 'package:flutter/material.dart';

import '../../../core/auth/role_permissions.dart';
import '../../../core/navigation/app_routes.dart';

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

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = collapsed ? 72.0 : 230.0;

    final visibleModules = FirefaNavigation.accessibleModules(role);

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
                itemCount: visibleModules.length,
                itemBuilder: (context, index) {
                  final module = visibleModules[index];

                  // Gunakan indeks asli agar DashboardPage
                  // tetap membuka modul yang benar.
                  final originalIndex = FirefaNavigation.modules.indexOf(
                    module,
                  );

                  final isActive = selectedIndex == originalIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Tooltip(
                      message: collapsed ? module.title : '',
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
                                      module.icon,
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
                                        module.icon,
                                        size: 23,
                                        color: isActive
                                            ? Colors.teal.shade700
                                            : Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          module.title,
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
