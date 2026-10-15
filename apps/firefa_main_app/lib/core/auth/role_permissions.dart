enum FirefaRole { owner, cashier }

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
      case FirefaRole.cashier:
        return 'Kasir';
    }
  }
}

class FirefaAccess {
  const FirefaAccess._();

  static Set<FirefaPermission> permissionsFor(FirefaRole role) {
    switch (role) {
      case FirefaRole.owner:
        return Set.unmodifiable(FirefaPermission.values);
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
    }
  }

  static bool can(FirefaRole role, FirefaPermission permission) =>
      permissionsFor(role).contains(permission);
}
