library;

/// Owner settings access controller foundation.

class OwnerSettingsAccessController {
  bool canManageSettings(String role) {
    return role.toLowerCase() == 'owner';
  }
}
