class FirefaStoreSettings {
  final String storeName;
  final String? logoUrl;
  final String primaryColor;
  final String themeMode;

  const FirefaStoreSettings({
    required this.storeName,
    this.logoUrl,
    required this.primaryColor,
    required this.themeMode,
  });
}
