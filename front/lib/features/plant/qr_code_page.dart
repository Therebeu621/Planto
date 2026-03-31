import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:planto/core/services/api_client.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/features/plant/qr_download_service.dart' as qr_download;

class QrCodePage extends StatefulWidget {
  final String plantId;
  final String plantName;
  final Dio? dio;

  const QrCodePage({super.key, required this.plantId, required this.plantName, this.dio});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  Uint8List? _qrBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    try {
      final dio = widget.dio ?? ApiClient.instance.dio;
      final response = await dio.get(
        '/api/v1/qrcode/plant/${widget.plantId}',
        queryParameters: {'size': 600},
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted) {
        setState(() {
          _qrBytes = Uint8List.fromList(response.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _downloadQrCode() {
    if (_qrBytes == null) return;

    qr_download.downloadQrCode(_qrBytes!.toList(), widget.plantName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code telecharge')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth - 112).clamp(150.0, 300.0);

    return Scaffold(
      appBar: AppBar(title: Text('QR Code - ${widget.plantName}')),
      body: Center(
        child: SingleChildScrollView(
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
                child: _buildQrContent(qrSize),
              ),
              const SizedBox(height: 32),
              Text(
                widget.plantName,
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
              ElevatedButton.icon(
                onPressed: _qrBytes != null ? _downloadQrCode : null,
                icon: const Icon(Icons.download),
                label: const Text('Telecharger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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

  Widget _buildQrContent(double qrSize) {
    if (_isLoading) {
      return SizedBox(
        width: qrSize,
        height: qrSize,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_qrBytes != null) {
      return Image.memory(
        _qrBytes!,
        width: qrSize,
        height: qrSize,
        fit: BoxFit.contain,
      );
    }
    return SizedBox(
      width: qrSize,
      height: qrSize,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('QR code indisponible', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
