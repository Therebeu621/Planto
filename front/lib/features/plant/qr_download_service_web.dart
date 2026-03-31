// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

void downloadQrCode(List<int> bytes, String plantName) {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'qr-$plantName.png')
    ..click();
  html.Url.revokeObjectUrl(url);
}
