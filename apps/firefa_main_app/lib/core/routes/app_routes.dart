import 'package:flutter/material.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/settings/owner_settings_page.dart';

class AppRoutes {
  static const String dashboard = '/';
  static const String ownerSettings = '/owner/settings';

  static Map<String, WidgetBuilder> routes = {
    dashboard: (_) => const DashboardPage(),
    ownerSettings: (_) => const OwnerSettingsPage(),
  };
}
