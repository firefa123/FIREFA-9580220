import 'package:flutter/material.dart';

import '../../core/auth/role_permissions.dart';
import 'role_dashboards/owner_dashboard.dart';
import 'role_dashboards/manager_dashboard.dart';
import 'role_dashboards/cashier_dashboard.dart';
import 'role_dashboards/kitchen_dashboard.dart';

class RoleDashboardRouter extends StatelessWidget {
  final FirefaRole role;

  const RoleDashboardRouter({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case FirefaRole.owner:
        return const OwnerDashboard();
      case FirefaRole.manager:
        return const ManagerDashboard();
      case FirefaRole.cashier:
        return const CashierDashboard();
      case FirefaRole.kitchenBar:
        return const KitchenDashboard();
    }
  }
}
