library;

/// Multi outlet branding controller foundation.
/// Resolves tenant branding and outlet override.

class MultiOutletBrandingController {
  MultiOutletBrandingController();

  String resolveBranding(String tenantBrand, String? outletBrand) {
    return outletBrand ?? tenantBrand;
  }
}
