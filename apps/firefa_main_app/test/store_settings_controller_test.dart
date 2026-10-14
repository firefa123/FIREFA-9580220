import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/settings/store_settings_controller.dart';
import 'package:firefa_main_app/features/settings/store_settings_model.dart';

void main() {
  group('FirefaStoreSettingsController', () {
    test('starts with sensible default branding settings', () {
      final controller = FirefaStoreSettingsController();

      expect(controller.settings.storeName, 'FIREFA');
      expect(controller.settings.primaryColor, '#008F83');
      expect(controller.settings.themeMode, 'system');
      expect(controller.settings.logoUrl, isNull);
    });

    test('updates store name after trimming and preserves other settings', () {
      final controller = FirefaStoreSettingsController(
        initialSettings: const FirefaStoreSettings(
          storeName: 'Old Store',
          logoUrl: 'https://example.com/logo.png',
          primaryColor: '#112233',
          themeMode: 'dark',
        ),
      );

      expect(controller.updateStoreName('  New Store  '), isTrue);
      expect(controller.settings.storeName, 'New Store');
      expect(controller.settings.logoUrl, 'https://example.com/logo.png');
      expect(controller.settings.primaryColor, '#112233');
      expect(controller.settings.themeMode, 'dark');
    });

    test('rejects empty or overlong store names without mutation', () {
      final controller = FirefaStoreSettingsController();
      final before = controller.settings;

      expect(controller.updateStoreName('  '), isFalse);
      expect(controller.updateStoreName('A' * 121), isFalse);
      expect(controller.settings.storeName, before.storeName);
    });

    test('accepts HTTP logo URLs and allows clearing logo', () {
      final controller = FirefaStoreSettingsController();

      expect(
        controller.updateLogo(' https://example.com/logo.png '),
        isTrue,
      );
      expect(controller.settings.logoUrl, 'https://example.com/logo.png');
      expect(controller.updateLogo(''), isTrue);
      expect(controller.settings.logoUrl, isNull);
    });

    test('rejects malformed and non-HTTP logo URLs', () {
      final controller = FirefaStoreSettingsController();

      expect(controller.updateLogo('not a URL'), isFalse);
      expect(controller.updateLogo('file:///logo.png'), isFalse);
      expect(controller.updateLogo('javascript:alert(1)'), isFalse);
      expect(controller.settings.logoUrl, isNull);
    });

    test('validates hex color and normalizes casing', () {
      final controller = FirefaStoreSettingsController();

      expect(controller.updatePrimaryColor(' #a1b2c3 '), isTrue);
      expect(controller.settings.primaryColor, '#A1B2C3');
      expect(controller.updatePrimaryColor('red'), isFalse);
      expect(controller.updatePrimaryColor('#FFF'), isFalse);
      expect(controller.settings.primaryColor, '#A1B2C3');
    });

    test('accepts only supported theme modes', () {
      final controller = FirefaStoreSettingsController();

      expect(controller.updateThemeMode('DARK'), isTrue);
      expect(controller.settings.themeMode, 'dark');
      expect(controller.updateThemeMode('light'), isTrue);
      expect(controller.settings.themeMode, 'light');
      expect(controller.updateThemeMode('system'), isTrue);
      expect(controller.settings.themeMode, 'system');
      expect(controller.updateThemeMode('auto-magical'), isFalse);
      expect(controller.settings.themeMode, 'system');
    });
  });
}
