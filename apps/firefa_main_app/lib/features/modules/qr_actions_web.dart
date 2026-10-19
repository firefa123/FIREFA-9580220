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
    final printWindow = html.window.open('', 'firefa_table_qr_print');
    if (printWindow == null) {
      throw StateError('Izinkan pop-up untuk mencetak QR.');
    }
    final safeTable = _escape(tableName);
    final safeOutlet = _escape(outletName);
    printWindow.document.open();
    printWindow.document.write('''
<!doctype html>
<html><head><meta charset="utf-8"><title>QR FIREFA - $safeTable</title>
<style>
body{font-family:Arial,sans-serif;text-align:center;padding:24px}
img{width:320px;height:320px;object-fit:contain}
@media print{button{display:none}}
</style></head><body>
<h1>$safeOutlet</h1><h2>$safeTable</h2>
<img src="$url" alt="QR pemesanan">
<p>Pindai untuk membuka halaman pemesanan meja.</p>
<button onclick="window.print()">Cetak</button>
<script>window.onload=()=>setTimeout(()=>window.print(),500)</script>
</body></html>
''');
    printWindow.document.close();
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
