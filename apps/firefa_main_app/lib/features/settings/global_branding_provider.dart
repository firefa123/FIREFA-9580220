class FirefaGlobalBrandingProvider {
  String storeName = 'FIREFA Store';
  String? logoUrl;
  String primaryColor = '#2E7D32';
  String themeMode = 'system';

  void updateBranding({
    String? name,
    String? logo,
    String? color,
    String? theme,
  }) {
    if (name != null) storeName = name;
    if (logo != null) logoUrl = logo;
    if (color != null) primaryColor = color;
    if (theme != null) themeMode = theme;
  }
}
