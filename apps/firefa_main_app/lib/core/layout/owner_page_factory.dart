import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/staff/presentation/pages/owner_staff_page.dart';

class OwnerPageFactory {
  static List<Widget> createPages() {
    return [
      const DashboardPage(),
      const Center(child: Text('Order Management')),
      const Center(child: Text('Menu Management')),
      const OwnerStaffPage(),
      const Center(child: Text('Outlet Management')),
      const Center(child: Text('Analytics Dashboard')),
      const Center(child: Text('Owner Settings')),
      const Center(child: Text('Profile')),
    ];
  }
}
