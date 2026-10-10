library;

/// Owner settings navigation foundation.

class OwnerSettingsRoute {
  final String name;

  const OwnerSettingsRoute(this.name);
}

const ownerSettingsRoutes = [
  OwnerSettingsRoute('store_profile'),
  OwnerSettingsRoute('branding'),
  OwnerSettingsRoute('theme'),
  OwnerSettingsRoute('staff_management'),
];
