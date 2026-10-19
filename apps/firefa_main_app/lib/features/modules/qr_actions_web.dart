// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class FirefaQrActions {
  static Future<void> download(String url, String filename) async {
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..target = '_blank'
      ..rel = 'noopener';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  static Future<void> print(String url, String tableName, String outletName) async {
    // Open the QR image in a dedicated tab. The browser's native print action
    // can print the image without relying on deprecated WindowBase.document APIs.
    html.window.open(url, '_blank', 'noopener');
    // Browsers may block the new tab; the user can allow pop-ups if needed.
    // `window.open` is typed as non-null in dart:html.
  }
}
