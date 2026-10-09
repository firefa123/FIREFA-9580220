import 'package:flutter/material.dart';

import 'widgets/stat_card.dart';
import 'widgets/revenue_card.dart';
import 'widgets/dashboard_sidebar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;
  bool sidebarCollapsed = true;

  String selectedOutlet = 'Semua Outlet';

  final List<String> outlets = const [
    'Semua Outlet',
    'Outlet Utama',
    'Outlet 2',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          DashboardSidebar(
            selectedIndex: selectedIndex,
            collapsed: sidebarCollapsed,
            onToggle: () {
              setState(() {
                sidebarCollapsed = !sidebarCollapsed;
              });
            },
            onSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopbar(),
                      const SizedBox(height: 28),
                      const Text(
                        'Dashboard Overview',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B4D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pantau performa operasional bisnis Anda.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildStats(),
                      const SizedBox(height: 24),
                      const RevenueCard(),
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
            const Text(
              'Welcome back, Owner',
              style: TextStyle(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _buildOutletSelector()),
            const SizedBox(width: 12),
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(Icons.person_outline, color: Color(0xFF00897B)),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [greeting, const SizedBox(height: 18), actions],
          );
        }

        return Row(
          children: [
            Expanded(child: greeting),
            const SizedBox(width: 16),
            Flexible(child: actions),
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
                title: "Orders",
                value: "245",
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 180,
              child: const StatCard(
                title: "Active Tables",
                value: "18",
                icon: Icons.table_bar_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 180,
              child: const StatCard(
                title: "Low Stock",
                value: "5",
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ],
        );
      },
    );
  }
}
