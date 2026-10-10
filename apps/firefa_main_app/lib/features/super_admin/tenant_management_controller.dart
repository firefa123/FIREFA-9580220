import 'tenant_management_model.dart';

class TenantManagementController {
  final List<TenantManagementModel> tenants = [];

  void addTenant(TenantManagementModel tenant) {
    tenants.add(tenant);
  }
}
