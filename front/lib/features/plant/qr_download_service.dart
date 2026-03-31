import 'qr_download_service_stub.dart'
    if (dart.library.html) 'qr_download_service_web.dart'
    as qr_download;

void downloadQrCode(List<int> bytes, String plantName) {
  qr_download.downloadQrCode(bytes, plantName);
}
