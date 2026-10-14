import 'store_settings_model.dart';

/// Validates and updates store branding preferences in memory.
/// Persistence and applying theme changes belong to the app-level settings store.
class FirefaStoreSettingsController {
  FirefaStoreSettingsController({
    FirefaStoreSettings? initialSettings,
  }) : _settings = initialSettings ??
            const FirefaStoreSettings(
              storeName: 'FIREFA',
              primaryColor: '#008F83',
              themeMode: 'system',
            );

  FirefaStoreSettings _settings;

  FirefaStoreSettings get settings => _settings;

  bool updateStoreName(String name) {
    final value = name.trim();
    if (value.isEmpty || value.length > 120) return false;
    _settings = FirefaStoreSettings(
      storeName: value,
      logoUrl: _settings.logoUrl,
      primaryColor: _settings.primaryColor,
      themeMode: _settings.themeMode,
    );
    return true;
  }

  bool updateLogo(String logoUrl) {
    final value = logoUrl.trim();
    if (value.isNotEmpty) {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return false;
      }
    }
    _settings = FirefaStoreSettings(
      storeName: _settings.storeName,
      logoUrl: value.isEmpty ? null : value,
      primaryColor: _settings.primaryColor,
      themeMode: _settings.themeMode,
    );
    return true;
  }

  bool updatePrimaryColor(String color) {
    final value = color.trim().toUpperCase();
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) return false;
    _settings = FirefaStoreSettings(
      storeName: _settings.storeName,
      logoUrl: _settings.logoUrl,
      primaryColor: value,
      themeMode: _settings.themeMode,
    );
    return true;
  }

  bool updateThemeMode(String mode) {
    final value = mode.trim().toLowerCase();
    if (!const {'system', 'light', 'dark'}.contains(value)) return false;
    _settings = FirefaStoreSettings(
      storeName: _settings.storeName,
      logoUrl: _settings.logoUrl,
      primaryColor: _settings.primaryColor,
      themeMode: value,
    );
    return true;
  }
}
