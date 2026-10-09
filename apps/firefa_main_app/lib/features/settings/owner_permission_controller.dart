/// FIREFA owner permission controller foundation.

class OwnerPermissionController {
  bool canManageStaff(String role) {
    return role == 'owner';
  }

  bool canAssignRole(String role) {
    return const [
      'manager',
      'kitchen',
      'cashier',
      'staff',
    ].contains(role);
  }
}
