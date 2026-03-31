// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> printQrCodeHtml(String htmlContent) async {
  try {
    final dynamic newWindow = html.window.open('', '_blank');
    newWindow.document.write(htmlContent);
    newWindow.document.close();
    newWindow.print();
    return true;
  } catch (_) {
    return false;
  }
}
