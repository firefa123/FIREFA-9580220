/// Branding preview controller foundation.

class BrandingPreviewController {
  String storeName = '';
  String logoUrl = '';
  String primaryColor = '#2E7D32';

  void updateBrand({
    String? name,
    String? logo,
    String? color,
  }) {
    storeName = name ?? storeName;
    logoUrl = logo ?? logoUrl;
    primaryColor = color ?? primaryColor;
  }
}
