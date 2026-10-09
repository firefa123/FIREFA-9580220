import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/staff/presentation/pages/owner_staff_page.dart';
import '../../features/settings/owner_settings_page.dart';

class OwnerPageAssembly {
  static List<Widget> pages() {
    return const [
      DashboardPage(),
      Scaffold(body: Center(child: Text('Order'))),
      Scaffold(body: Center(child: Text('Menu'))),
      OwnerStaffPage(),
      Scaffold(body: Center(child: Text('Outlet'))),
      Scaffold(body: Center(child: Text('Analytics'))),
      OwnerSettingsPage(),
      Scaffold(body: Center(child: Text('Profile'))),
    ];
  }
}
