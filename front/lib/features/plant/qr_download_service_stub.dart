import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void downloadQrCode(List<int> bytes, String plantName) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/qr-$plantName.png');
  await file.writeAsBytes(Uint8List.fromList(bytes));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      title: 'QR Code - $plantName',
    ),
  );
}
