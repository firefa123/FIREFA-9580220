// TODO Implement this library.

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
  settingsManage,
}

extension FirefaRoleDetails on FirefaRole {
  String get label {
    switch (this) {
      case FirefaRole.owner:
        return 'Owner';
      case FirefaRole.manager:
        return 'Manager';
      case FirefaRole.cashier:
        return 'Cashier';
      case FirefaRole.kitchenBar:
        return 'Kitchen / Bar';
    }
  }
}

class FirefaAccess {
  const FirefaAccess._();

  static Set<FirefaPermission> permissionsFor(FirefaRole role) {
    switch (role) {
      case FirefaRole.owner:
        return FirefaPermission.values.toSet();

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
        };

      case FirefaRole.cashier:
        return {
          FirefaPermission.dashboardView,
          FirefaPermission.posAccess,
          FirefaPermission.ordersView,
          FirefaPermission.ordersManage,
          FirefaPermission.tablesManage,
        };

      case FirefaRole.kitchenBar:
        return {FirefaPermission.ordersView, FirefaPermission.ordersManage};
    }
  }

  static bool can(FirefaRole role, FirefaPermission permission) {
    return permissionsFor(role).contains(permission);
  }
}
