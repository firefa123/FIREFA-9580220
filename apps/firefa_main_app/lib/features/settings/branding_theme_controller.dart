/// FIREFA branding and theme controller foundation

class BrandingThemeController {
  String themeMode = 'system';
  String primaryColor = '#2E7D32';

  void setThemeMode(String mode) {
    themeMode = mode;
  }

  void setPrimaryColor(String color) {
    primaryColor = color;
  }
}
