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
}

extension FirefaRoleDetails on FirefaRole {
  String get label {
    switch (this) {
      case FirefaRole.owner:
        return 'Owner';
      case FirefaRole.cashier:
        return 'Cashier';
    }
  }
}

class FirefaAccess {
  const FirefaAccess._();

  static Set<FirefaPermission> permissionsFor(FirefaRole role) {
    switch (role) {
      case FirefaRole.owner:
        return FirefaPermission.values.toSet();
      case FirefaRole.cashier:
        return {
          FirefaPermission.posAccess,
          FirefaPermission.ordersView,
          FirefaPermission.ordersManage,
          FirefaPermission.tablesManage,
          FirefaPermission.printerManage,
        };
    }
  }

  static bool can(FirefaRole role, FirefaPermission permission) =>
      permissionsFor(role).contains(permission);
}
