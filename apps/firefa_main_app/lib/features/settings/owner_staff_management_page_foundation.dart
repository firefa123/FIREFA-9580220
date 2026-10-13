// FIREFA owner staff management page foundation.
// Owner manages outlet staff roles and access.

class OwnerStaffManagementPageFoundation {
  final List<String> roles;

  const OwnerStaffManagementPageFoundation({
    this.roles = const [
      'manager',
      'kitchen',
      'cashier',
      'staff',
    ],
  });
}
