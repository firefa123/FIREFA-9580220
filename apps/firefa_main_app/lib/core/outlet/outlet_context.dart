import '../auth/role_permissions.dart';

class FirefaOutlet {
  final String id;
  final String name;

  const FirefaOutlet({required this.id, required this.name});
}

class FirefaOutletContext {
  final FirefaRole role;
  final List<FirefaOutlet> assignedOutlets;

  const FirefaOutletContext({
    required this.role,
    required this.assignedOutlets,
  });

  bool get canViewAllOutlets {
    return role == FirefaRole.owner || role == FirefaRole.manager;
  }

  List<FirefaOutlet> get availableOutlets {
    return assignedOutlets;
  }

  bool canAccessOutlet(String outletId) {
    return assignedOutlets.any((outlet) => outlet.id == outletId);
  }

  static FirefaOutletContext demo(FirefaRole role) {
    const outletUtama = FirefaOutlet(id: 'outlet-001', name: 'Outlet Utama');

    const outletDua = FirefaOutlet(id: 'outlet-002', name: 'Outlet 2');

    switch (role) {
      case FirefaRole.owner:
      case FirefaRole.manager:
        return FirefaOutletContext(
          role: role,
          assignedOutlets: [outletUtama, outletDua],
        );

      case FirefaRole.cashier:
      case FirefaRole.kitchenBar:
        return FirefaOutletContext(role: role, assignedOutlets: [outletUtama]);
    }
  }
}
