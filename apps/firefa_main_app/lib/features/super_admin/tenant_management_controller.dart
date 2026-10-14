import 'tenant_management_model.dart';

/// In-memory tenant administration for the Super Admin workflow.
class TenantManagementController {
  final List<TenantManagementModel> _tenants = [];

  List<TenantManagementModel> get tenants =>
      List.unmodifiable(_tenants);

  void addTenant(TenantManagementModel tenant) {
    final normalized = _normalize(tenant);
    if (_tenants.any((existing) => existing.tenantId == normalized.tenantId)) {
      throw StateError('ID tenant sudah terdaftar.');
    }
    _tenants.add(normalized);
  }

  bool updateTenant(String currentTenantId, TenantManagementModel updated) {
    final currentId = currentTenantId.trim();
    final index = _tenants.indexWhere((tenant) => tenant.tenantId == currentId);
    if (index < 0) return false;

    final normalized = _normalize(updated);
    if (_tenants.any((tenant) =>
        tenant.tenantId == normalized.tenantId && tenant.tenantId != currentId)) {
      throw StateError('ID tenant sudah digunakan.');
    }
    _tenants[index] = normalized;
    return true;
  }

  bool setTenantActive(String tenantId, bool active) {
    final id = tenantId.trim();
    final index = _tenants.indexWhere((tenant) => tenant.tenantId == id);
    if (index < 0) return false;
    final current = _tenants[index];
    _tenants[index] = TenantManagementModel(
      tenantId: current.tenantId,
      name: current.name,
      active: active,
    );
    return true;
  }

  bool removeTenant(String tenantId) {
    final id = tenantId.trim();
    final index = _tenants.indexWhere((tenant) => tenant.tenantId == id);
    if (index < 0) return false;
    _tenants.removeAt(index);
    return true;
  }

  TenantManagementModel? findById(String tenantId) {
    final id = tenantId.trim();
    for (final tenant in _tenants) {
      if (tenant.tenantId == id) return tenant;
    }
    return null;
  }

  List<TenantManagementModel> search(String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return tenants;
    return List.unmodifiable(_tenants.where((tenant) =>
        tenant.tenantId.toLowerCase().contains(value) ||
        tenant.name.toLowerCase().contains(value)));
  }

  List<TenantManagementModel> get activeTenants =>
      List.unmodifiable(_tenants.where((tenant) => tenant.active));

  TenantManagementModel _normalize(TenantManagementModel tenant) {
    final id = tenant.tenantId.trim();
    final name = tenant.name.trim();
    if (id.isEmpty || id.length > 100) {
      throw ArgumentError.value(
        tenant.tenantId,
        'tenantId',
        'ID tenant tidak valid.',
      );
    }
    if (name.isEmpty || name.length > 160) {
      throw ArgumentError.value(tenant.name, 'name', 'Nama tenant tidak valid.');
    }
    return TenantManagementModel(
      tenantId: id,
      name: name,
      active: tenant.active,
    );
  }
}
