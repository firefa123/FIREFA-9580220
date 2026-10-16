import 'package:flutter/foundation.dart';

import '../auth/role_permissions.dart';
import '../../features/modules/backend_client.dart';

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
  Set<String>? _authorizedServerOutletIds;
  Map<String, String> _serverOutletMap = const {};

  FirefaRole get role => _role;
  String get selectedOutletId => _selectedOutletId;
  bool get isBackendSession => _authorizedServerOutletIds != null;

  bool get canViewAllOutlets => _role == FirefaRole.owner;

  List<FirefaOutlet> get accessibleOutlets {
    if (_authorizedServerOutletIds case final authorized?) {
      return List.unmodifiable(availableOutlets.where((outlet) {
        final serverId = _serverOutletMap[outlet.id];
        return serverId != null && authorized.contains(serverId);
      }));
    }
    if (canViewAllOutlets) return List.unmodifiable(availableOutlets);
    return List.unmodifiable(
      availableOutlets.where((outlet) => outlet.id == 'outlet-001'),
    );
  }

  FirefaOutlet get selectedOutlet {
    for (final outlet in availableOutlets) {
      if (outlet.id == _selectedOutletId) return outlet;
    }
    return accessibleOutlets.first;
  }

  String get selectedOutletName => selectedOutlet.name;

  bool canAccessOutlet(String outletId) =>
      accessibleOutlets.any((outlet) => outlet.id == outletId);

  String resolveAuthorizedServerOutletId(String localOutletId) {
    if (!canAccessOutlet(localOutletId)) {
      throw const FormatException('Outlet lokal tidak termasuk akses sesi aktif.');
    }
    final authorized = _authorizedServerOutletIds;
    if (authorized == null) {
      throw const FormatException('Sesi backend belum aktif.');
    }
    return FirefaBackendConfig.resolveServerOutletId(
      localOutletId: localOutletId,
      mapping: _serverOutletMap,
      authorizedServerOutletIds: authorized,
    );
  }

  void initializeForSession(FirefaBackendSession session) {
    if (session.tenantId.trim().isEmpty || session.outletIds.isEmpty) {
      throw const FormatException('Sesi tidak memiliki tenant atau outlet yang valid.');
    }
    final mapping = FirefaBackendConfig.validatedOutletMap;
    final authorized = session.outletIds.toSet();
    final matching = availableOutlets.where((outlet) {
      final serverId = mapping[outlet.id];
      return serverId != null && authorized.contains(serverId);
    }).toList();
    if (matching.isEmpty) {
      throw const FormatException(
        'Tidak ada pemetaan outlet lokal yang cocok dengan akses akun ini. Periksa FIREFA_OUTLET_MAP.',
      );
    }

    _role = session.role;
    _serverOutletMap = mapping;
    _authorizedServerOutletIds = authorized;
    if (!matching.any((outlet) => outlet.id == _selectedOutletId)) {
      _selectedOutletId = matching.first.id;
    }
    notifyListeners();
  }

  /// Keep the authenticated server outlet scope when DashboardPage initializes.
  void initializeForRole(FirefaRole role) {
    _role = role;
    if (!canAccessOutlet(_selectedOutletId)) {
      final accessible = accessibleOutlets;
      if (accessible.isNotEmpty) _selectedOutletId = accessible.first.id;
    }
    notifyListeners();
  }

  bool selectOutlet(String outletId) {
    if (!canAccessOutlet(outletId)) return false;
    if (_selectedOutletId == outletId) return true;
    _selectedOutletId = outletId;
    notifyListeners();
    return true;
  }

  void reset() {
    _role = FirefaRole.owner;
    _selectedOutletId = 'outlet-001';
    _authorizedServerOutletIds = null;
    _serverOutletMap = const {};
    notifyListeners();
  }
}
