library;

/// Branding state controller foundation.

class BrandingStateController {
  bool darkModeEnabled = false;
  String primaryColor = '#2E7D32';

  void toggleDarkMode() {
    darkModeEnabled = !darkModeEnabled;
  }

  void updateColor(String color) {
    primaryColor = color;
  }
}
