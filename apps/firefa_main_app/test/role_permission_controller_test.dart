import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/staff/role_permission_controller.dart';
import 'package:firefa_main_app/features/staff/role_permission_model.dart';

void main() {
  group('RolePermissionController', () {
    test('adds a role and checks its permissions', () {
      final controller = RolePermissionController();

      controller.addRole(const RolePermissionModel(
        role: ' Cashier ',
        permissions: ['pos_access', 'orders_view'],
      ));

      expect(controller.roles.single.role, 'Cashier');
      expect(controller.hasPermission('Cashier', 'pos_access'), isTrue);
      expect(controller.hasPermission('Cashier', 'settings_manage'), isFalse);
      expect(controller.hasPermission('Unknown', 'pos_access'), isFalse);
    });

    test('normalizes duplicate permissions and trims permission strings', () {
      final controller = RolePermissionController();

      controller.addRole(const RolePermissionModel(
        role: 'Manager',
        permissions: ['orders_view', ' orders_view ', 'reports_view'],
      ));

      expect(
        controller.roles.single.permissions,
        ['orders_view', 'reports_view'],
      );
    });

    test('rejects duplicate role names', () {
      final controller = RolePermissionController();
      controller.addRole(const RolePermissionModel(
        role: 'Cashier',
        permissions: ['pos_access'],
      ));

      expect(
        () => controller.addRole(const RolePermissionModel(
          role: ' Cashier ',
          permissions: ['orders_view'],
        )),
        throwsStateError,
      );
      expect(controller.roles, hasLength(1));
    });

    test('rejects empty role names and empty permissions', () {
      final controller = RolePermissionController();

      expect(
        () => controller.addRole(const RolePermissionModel(
          role: ' ',
          permissions: ['pos_access'],
        )),
        throwsArgumentError,
      );
      expect(
        () => controller.addRole(const RolePermissionModel(
          role: 'Manager',
          permissions: [' '],
        )),
        throwsArgumentError,
      );
      expect(controller.roles, isEmpty);
    });

    test('updates a role and prevents collisions', () {
      final controller = RolePermissionController();
      controller.addRole(const RolePermissionModel(
        role: 'Cashier',
        permissions: ['pos_access'],
      ));
      controller.addRole(const RolePermissionModel(
        role: 'Manager',
        permissions: ['reports_view'],
      ));

      expect(
        controller.updateRole(
          'Cashier',
          const RolePermissionModel(
            role: 'Front Desk',
            permissions: ['orders_view'],
          ),
        ),
        isTrue,
      );
      expect(controller.hasPermission('Front Desk', 'orders_view'), isTrue);
      expect(
        () => controller.updateRole(
          'Front Desk',
          const RolePermissionModel(
            role: 'Manager',
            permissions: ['pos_access'],
          ),
        ),
        throwsStateError,
      );
      expect(controller.updateRole('Missing', const RolePermissionModel(
        role: 'New Role',
        permissions: ['pos_access'],
      )), isFalse);
    });

    test('removes roles and exposes an unmodifiable collection', () {
      final controller = RolePermissionController();
      controller.addRole(const RolePermissionModel(
        role: 'Kitchen',
        permissions: ['orders_view'],
      ));

      expect(controller.removeRole('Kitchen'), isTrue);
      expect(controller.removeRole('Kitchen'), isFalse);
      expect(controller.roles, isEmpty);

      expect(
        () => controller.roles.add(const RolePermissionModel(
          role: 'Another',
          permissions: ['pos_access'],
        )),
        throwsUnsupportedError,
      );
    });
  });
}
