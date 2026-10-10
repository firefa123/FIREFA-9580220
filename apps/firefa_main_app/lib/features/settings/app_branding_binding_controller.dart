class FirefaBrandingBindingController {
  String activeStoreName = 'FIREFA Store';
  String activeTheme = 'system';

  void applyStoreBranding({
    required String storeName,
    required String theme,
  }) {
    activeStoreName = storeName;
    activeTheme = theme;
  }
}
