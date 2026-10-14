import 'role_permission_model.dart';

/// Manages custom role permission definitions in memory.
class RolePermissionController {
  final List<RolePermissionModel> _roles = [];

  List<RolePermissionModel> get roles => List.unmodifiable(_roles);

  void addRole(RolePermissionModel role) {
    final normalized = _normalize(role);
    if (_roles.any((existing) => existing.role == normalized.role)) {
      throw StateError('Role sudah terdaftar.');
    }
    _roles.add(normalized);
  }

  bool updateRole(String currentRole, RolePermissionModel updatedRole) {
    final current = currentRole.trim();
    final index = _roles.indexWhere((entry) => entry.role == current);
    if (index < 0) return false;

    final normalized = _normalize(updatedRole);
    if (_roles.any(
      (entry) => entry.role == normalized.role && entry.role != current,
    )) {
      throw StateError('Nama role sudah digunakan.');
    }

    _roles[index] = normalized;
    return true;
  }

  bool removeRole(String role) {
    final normalized = role.trim();
    final index = _roles.indexWhere((entry) => entry.role == normalized);
    if (index < 0) return false;
    _roles.removeAt(index);
    return true;
  }

  bool hasPermission(String role, String permission) {
    final normalizedRole = role.trim();
    final normalizedPermission = permission.trim();
    if (normalizedRole.isEmpty || normalizedPermission.isEmpty) return false;

    final item = _roles.where((entry) => entry.role == normalizedRole);
    if (item.isEmpty) return false;
    return item.first.permissions.contains(normalizedPermission);
  }

  RolePermissionModel _normalize(RolePermissionModel role) {
    final name = role.role.trim();
    final permissions = role.permissions
        .map((permission) => permission.trim())
        .where((permission) => permission.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (name.isEmpty || name.length > 80) {
      throw ArgumentError.value(role.role, 'role', 'Nama role tidak valid.');
    }
    if (permissions.length != role.permissions.length ||
        role.permissions.any((permission) => permission.trim().isEmpty)) {
      // Reject invalid entries rather than silently assigning an unintended set.
      throw ArgumentError.value(
        role.permissions,
        'permissions',
        'Permission tidak boleh kosong.',
      );
    }

    return RolePermissionModel(
      role: name,
      permissions: List.unmodifiable(permissions),
    );
  }
}
