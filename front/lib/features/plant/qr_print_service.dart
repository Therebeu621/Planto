import 'qr_print_service_stub.dart'
    if (dart.library.html) 'qr_print_service_web.dart'
    as qr_print;

Future<bool> printQrCodeHtml(String htmlContent) {
  return qr_print.printQrCodeHtml(htmlContent);
}
