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
    final opened = html.window.open(url, '_blank', 'noopener');
    if (opened == null) {
      throw StateError('Izinkan pop-up untuk mencetak QR.');
    }
  }
}
