import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/features/plant/qr_code_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      home: QrCodePage(plantId: 'p1', plantName: 'My Plant'),
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
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('QR Code - My Plant'), findsOneWidget);
    expect(find.text('My Plant'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.textContaining('Scannez ce QR code'), findsOneWidget);

    FlutterError.onError = origOnError;
  });

  testWidgets('share button shows snackbar', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final origOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflow')) return;
      origOnError?.call(details);
    };

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.tap(find.text('Partager'));
    await tester.pump();
    expect(find.text('QR code pret a partager'), findsOneWidget);

    FlutterError.onError = origOnError;
  });
}
