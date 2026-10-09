import 'package:flutter/foundation.dart';

import '../auth/role_permissions.dart';

class FirefaOutlet {
  final String id;
  final String name;

  const FirefaOutlet({required this.id, required this.name});
}

class FirefaActiveOutletStore extends ChangeNotifier {
  FirefaActiveOutletStore._();

  static final FirefaActiveOutletStore instance = FirefaActiveOutletStore._();

  static const String allOutletsId = 'all';

  static const List<FirefaOutlet> availableOutlets = [
    FirefaOutlet(id: 'outlet-001', name: 'Outlet Utama'),
    FirefaOutlet(id: 'outlet-002', name: 'Outlet 2'),
  ];

  FirefaRole _role = FirefaRole.owner;
  String _selectedOutletId = 'outlet-001';

  FirefaRole get role => _role;
  String get selectedOutletId => _selectedOutletId;

  bool get canViewAllOutlets =>
      _role == FirefaRole.owner || _role == FirefaRole.manager;

  List<FirefaOutlet> get accessibleOutlets {
    if (canViewAllOutlets) {
      return List.unmodifiable(availableOutlets);
    }

    // Penugasan outlet demo untuk Cashier dan Kitchen/Bar.
    // Nantinya diambil dari membership pengguna di backend.
    return List.unmodifiable(
      availableOutlets.where((outlet) => outlet.id == 'outlet-001'),
    );
  }

  FirefaOutlet get selectedOutlet {
    for (final outlet in availableOutlets) {
      if (outlet.id == _selectedOutletId) {
        return outlet;
      }
    }

    return availableOutlets.first;
  }

  String get selectedOutletName => selectedOutlet.name;

  bool canAccessOutlet(String outletId) {
    return accessibleOutlets.any((outlet) => outlet.id == outletId);
  }

  void initializeForRole(FirefaRole role) {
    _role = role;

    if (!canAccessOutlet(_selectedOutletId)) {
      _selectedOutletId = accessibleOutlets.first.id;
    }

    notifyListeners();
  }

  bool selectOutlet(String outletId) {
    if (!canAccessOutlet(outletId)) {
      return false;
    }

    if (_selectedOutletId == outletId) {
      return true;
    }

    _selectedOutletId = outletId;
    notifyListeners();
    return true;
  }

  void reset() {
    _role = FirefaRole.owner;
    _selectedOutletId = 'outlet-001';
    notifyListeners();
  }
}
