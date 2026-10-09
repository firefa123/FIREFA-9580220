import 'package:flutter/material.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

class AppRoutes {
  static const String dashboard = '/';

  static Map<String, WidgetBuilder> routes = {
    dashboard: (_) => const DashboardPage(),
  };
}
