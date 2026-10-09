library;

/// Multi outlet branding scope foundation.
/// Defines tenant default branding and outlet override concept.

class MultiOutletBrandingScope {
  final String tenantId;
  final String? outletId;
  final String storeName;
  final String primaryColor;
  final bool isOutletOverride;

  const MultiOutletBrandingScope({
    required this.tenantId,
    this.outletId,
    required this.storeName,
    required this.primaryColor,
    this.isOutletOverride = false,
  });
}
