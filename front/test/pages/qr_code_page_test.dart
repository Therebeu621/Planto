import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/features/plant/qr_code_page.dart';
import '../test_helpers.dart';

const _validQrPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x00,
  0x00,
  0x02,
  0x00,
  0x01,
  0xE5,
  0x27,
  0xDE,
  0xFC,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    mockInterceptor.addMockResponse(
      '/api/v1/qrcode/plant/p1',
      data: _validQrPng,
    );
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: QrCodePage(
        plantId: 'p1',
        plantName: 'My Plant',
        dio: dio,
      ),
    );
  }

  testWidgets('renders without crashing', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final origOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflow')) return;
      origOnError?.call(details);
    };

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('QR Code - My Plant'), findsOneWidget);
    expect(find.text('My Plant'), findsOneWidget);
    expect(find.text('Telecharger'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.textContaining('Scannez ce QR code'), findsOneWidget);

    FlutterError.onError = origOnError;
  });
}
