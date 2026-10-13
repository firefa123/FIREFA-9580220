import 'role_permission_model.dart';

class RolePermissionController {
  final List<RolePermissionModel> roles = [];

  void addRole(RolePermissionModel role) {
    roles.add(role);
  }

  bool hasPermission(String role, String permission) {
    final item = roles.where((e) => e.role == role).firstOrNull;
    return item?.permissions.contains(permission) ?? false;
  }
}
