import 'package:flutter/material.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/theme/app_theme.dart';

class QrCodePage extends StatelessWidget {
  final String plantId;
  final String plantName;

  const QrCodePage({super.key, required this.plantId, required this.plantName});

  @override
  Widget build(BuildContext context) {
    final qrUrl = '${AppConstants.apiBaseUrl}/api/v1/qrcode/plant/$plantId?size=600';

    return Scaffold(
      appBar: AppBar(title: Text('QR Code - $plantName')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Image.network(
                  qrUrl,
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 250, height: 250,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: 250, height: 250,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('QR code indisponible', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                plantName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Scannez ce QR code pour acceder a la fiche de cette plante',
                style: TextStyle(color: AppTheme.textSecondaryC(context), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR code pret a partager')),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Partager'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
