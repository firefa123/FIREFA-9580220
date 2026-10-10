library;

/// Branding persistence model foundation.
/// Stores branding configuration for offline cache and sync preparation.

class BrandingPersistenceModel {
  final String storeName;
  final String? logoUrl;
  final String primaryColor;
  final String themeMode;

  const BrandingPersistenceModel({
    required this.storeName,
    this.logoUrl,
    required this.primaryColor,
    required this.themeMode,
  });
}
