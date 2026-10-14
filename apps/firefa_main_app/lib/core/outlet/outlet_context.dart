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

  bool get canViewAllOutlets => role == FirefaRole.owner;

  List<FirefaOutlet> get availableOutlets => assignedOutlets;

  bool canAccessOutlet(String outletId) =>
      assignedOutlets.any((outlet) => outlet.id == outletId);

  static FirefaOutletContext demo(FirefaRole role) {
    const outletUtama = FirefaOutlet(id: 'outlet-001', name: 'Outlet Utama');
    const outletDua = FirefaOutlet(id: 'outlet-002', name: 'Outlet 2');

    switch (role) {
      case FirefaRole.owner:
        return FirefaOutletContext(
          role: role,
          assignedOutlets: [outletUtama, outletDua],
        );
      case FirefaRole.cashier:
        return FirefaOutletContext(
          role: role,
          assignedOutlets: [outletUtama],
        );
    }
  }
}
