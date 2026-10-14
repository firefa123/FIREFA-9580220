import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/super_admin/tenant_management_controller.dart';
import 'package:firefa_main_app/features/super_admin/tenant_management_model.dart';

void main() {
  group('TenantManagementController', () {
    test('adds normalized tenants and finds them by ID', () {
      final controller = TenantManagementController();
      controller.addTenant(const TenantManagementModel(
        tenantId: ' tenant-1 ',
        name: '  Tenant One ',
        active: true,
      ));

      expect(controller.tenants.single.tenantId, 'tenant-1');
      expect(controller.tenants.single.name, 'Tenant One');
      expect(controller.findById(' tenant-1 ')?.active, isTrue);
    });

    test('rejects duplicate tenant IDs and invalid fields', () {
      final controller = TenantManagementController();
      controller.addTenant(const TenantManagementModel(
        tenantId: 'tenant-1',
        name: 'Tenant One',
        active: true,
      ));

      expect(
        () => controller.addTenant(const TenantManagementModel(
          tenantId: ' tenant-1 ',
          name: 'Another',
          active: true,
        )),
        throwsStateError,
      );
      expect(
        () => controller.addTenant(const TenantManagementModel(
          tenantId: ' ',
          name: 'Tenant Two',
          active: true,
        )),
        throwsArgumentError,
      );
      expect(
        () => controller.addTenant(const TenantManagementModel(
          tenantId: 'tenant-2',
          name: ' ',
          active: true,
        )),
        throwsArgumentError,
      );
      expect(controller.tenants, hasLength(1));
    });

    test('updates tenants and prevents ID collisions', () {
      final controller = TenantManagementController()
        ..addTenant(const TenantManagementModel(
          tenantId: 'tenant-1',
          name: 'Tenant One',
          active: true,
        ))
        ..addTenant(const TenantManagementModel(
          tenantId: 'tenant-2',
          name: 'Tenant Two',
          active: false,
        ));

      expect(
        controller.updateTenant(
          'tenant-1',
          const TenantManagementModel(
            tenantId: 'tenant-1',
            name: 'Updated One',
            active: false,
          ),
        ),
        isTrue,
      );
      expect(controller.findById('tenant-1')?.name, 'Updated One');
      expect(
        () => controller.updateTenant(
          'tenant-1',
          const TenantManagementModel(
            tenantId: 'tenant-2',
            name: 'Collision',
            active: true,
          ),
        ),
        throwsStateError,
      );
      expect(
        controller.updateTenant(
          'missing',
          const TenantManagementModel(
            tenantId: 'tenant-3',
            name: 'Tenant Three',
            active: true,
          ),
        ),
        isFalse,
      );
    });

    test('activates and deactivates a tenant', () {
      final controller = TenantManagementController()
        ..addTenant(const TenantManagementModel(
          tenantId: 'tenant-1',
          name: 'Tenant One',
          active: true,
        ));

      expect(controller.setTenantActive('tenant-1', false), isTrue);
      expect(controller.findById('tenant-1')?.active, isFalse);
      expect(controller.activeTenants, isEmpty);
      expect(controller.setTenantActive('tenant-1', true), isTrue);
      expect(controller.activeTenants, hasLength(1));
      expect(controller.setTenantActive('missing', true), isFalse);
    });

    test('searches tenant ID and name case-insensitively', () {
      final controller = TenantManagementController()
        ..addTenant(const TenantManagementModel(
          tenantId: 'tenant-1',
          name: 'Coffee House',
          active: true,
        ))
        ..addTenant(const TenantManagementModel(
          tenantId: 'tenant-2',
          name: 'Food Court',
          active: true,
        ));

      expect(controller.search('coffee'), hasLength(1));
      expect(controller.search('TENANT-2'), hasLength(1));
      expect(controller.search(''), hasLength(2));
      expect(controller.search('missing'), isEmpty);
    });

    test('removes tenant and protects the returned collection', () {
      final controller = TenantManagementController()
        ..addTenant(const TenantManagementModel(
          tenantId: 'tenant-1',
          name: 'Tenant One',
          active: true,
        ));

      expect(controller.removeTenant('tenant-1'), isTrue);
      expect(controller.removeTenant('tenant-1'), isFalse);
      expect(controller.findById('tenant-1'), isNull);
      expect(() => controller.tenants.clear(), throwsUnsupportedError);
    });
  });
}
