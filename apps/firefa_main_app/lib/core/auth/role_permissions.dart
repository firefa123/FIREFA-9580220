enum FirefaRole { owner, manager, cashier, kitchenBar }

enum FirefaPermission {
  dashboardView,
  posAccess,
  ordersView,
  ordersManage,
  tablesManage,
  menuManage,
  inventoryManage,
  reportsView,
  conflictManage,
  settingsManage,
  printerManage,
  cashierShiftManage,
  staffManage,
  outletsManage,
  documentSettingsManage,
  auditLogView,
}

extension FirefaRoleDetails on FirefaRole {
  String get label {
    switch (this) {
      case FirefaRole.owner:
        return 'Owner';
      case FirefaRole.manager:
        return 'Manager';
      case FirefaRole.cashier:
        return 'Kasir';
      case FirefaRole.kitchenBar:
        return 'Kitchen/Bar';
    }
  }
}

class FirefaAccess {
  const FirefaAccess._();

  static Set<FirefaPermission> permissionsFor(FirefaRole role) {
    switch (role) {
      case FirefaRole.owner:
        return Set.unmodifiable(FirefaPermission.values);
      case FirefaRole.manager:
        return {
          FirefaPermission.dashboardView,
          FirefaPermission.posAccess,
          FirefaPermission.ordersView,
          FirefaPermission.ordersManage,
          FirefaPermission.tablesManage,
          FirefaPermission.menuManage,
          FirefaPermission.inventoryManage,
          FirefaPermission.reportsView,
          FirefaPermission.conflictManage,
          FirefaPermission.printerManage,
          FirefaPermission.cashierShiftManage,
          FirefaPermission.staffManage,
          FirefaPermission.auditLogView,
        };
      case FirefaRole.cashier:
        return {
          FirefaPermission.dashboardView,
          FirefaPermission.posAccess,
          FirefaPermission.ordersView,
          FirefaPermission.ordersManage,
          FirefaPermission.tablesManage,
          FirefaPermission.printerManage,
          FirefaPermission.cashierShiftManage,
        };
      case FirefaRole.kitchenBar:
        return {
          FirefaPermission.dashboardView,
          FirefaPermission.ordersView,
          FirefaPermission.printerManage,
        };
    }
  }

  static bool can(FirefaRole role, FirefaPermission permission) =>
      permissionsFor(role).contains(permission);
}
