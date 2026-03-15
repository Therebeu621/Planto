import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/iot_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/features/iot/iot_sensors_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late IotService iotService;
  late HouseService houseService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    iotService = IotService(dio: dio);
    houseService = HouseService(dio: dio);
  });

  void addHouse() {
    mockInterceptor.addMockResponse('/api/v1/houses', data: [
      {
        'id': 'h1',
        'name': 'Maison',
        'inviteCode': 'ABC',
        'memberCount': 1,
        'roomCount': 1,
        'isActive': true,
      },
    ]);
  }

  void addSensors({bool withPlant = false}) {
    addHouse();
    mockInterceptor.addMockResponse('/api/v1/iot/house/h1/sensors', data: [
      {
        'id': 's1',
        'sensorType': 'HUMIDITY',
        'sensorTypeDisplay': 'Humidite',
        'deviceId': 'arduino-001',
        'label': 'Capteur salon',
        'lastValue': 65.0,
        'unit': '%',
        'plantNickname': withPlant ? 'Ficus' : null,
      },
      {
        'id': 's2',
        'sensorType': 'TEMPERATURE',
        'sensorTypeDisplay': 'Temperature',
        'deviceId': 'arduino-002',
        'label': null,
        'lastValue': 22.5,
        'unit': '°C',
        'plantNickname': null,
      },
    ]);
  }

  void addEmptySensors() {
    addHouse();
    mockInterceptor.addMockResponse(
        '/api/v1/iot/house/h1/sensors', data: <Map<String, dynamic>>[]);
  }

  void addSensorWithNoValue() {
    addHouse();
    mockInterceptor.addMockResponse('/api/v1/iot/house/h1/sensors', data: [
      {
        'id': 's3',
        'sensorType': 'LUMINOSITY',
        'sensorTypeDisplay': 'Luminosite',
        'deviceId': 'arduino-003',
        'label': 'Capteur lumiere',
        'lastValue': null,
        'unit': 'lux',
        'plantNickname': null,
      },
    ]);
  }

  Widget buildPage() {
    return MaterialApp(
      home: IotSensorsPage(
        iotService: iotService,
        houseService: houseService,
      ),
    );
  }

  group('IotSensorsPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      await tester.pumpWidget(buildPage());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows appbar with title', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Capteurs IoT'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows sensor cards with labels and values', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Capteur salon'), findsOneWidget);
      expect(find.text('arduino-001'), findsOneWidget);
      expect(find.text('65.0'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.text('22.5'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows correct icons per sensor type', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.water_drop), findsWidgets);
      expect(find.byIcon(Icons.thermostat), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows plant nickname when associated', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors(withPlant: true);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Plante: Ficus'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows -- for sensor with no value', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensorWithNoValue();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('--'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows empty state with text and add button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addEmptySensors();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucun capteur'), findsOneWidget);
      expect(find.textContaining('Connectez un Arduino'), findsOneWidget);
      expect(find.text('Ajouter un capteur'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add button opens add sensor dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un capteur'), findsWidgets);
      expect(find.text('Type de capteur'), findsOneWidget);
      expect(find.text('ID appareil *'), findsOneWidget);
      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Ajouter'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog cancel closes', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Type de capteur'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('add sensor dialog creates sensor with success', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      mockInterceptor.addMockResponse('/api/v1/iot/house/h1/sensors',
          data: {'id': 's3', 'sensorType': 'HUMIDITY', 'deviceId': 'new-001'});

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'ID appareil *'), 'new-001');
      // Find the ElevatedButton with 'Ajouter' inside the dialog
      final addButtons = find.widgetWithText(ElevatedButton, 'Ajouter');
      await tester.tap(addButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('Capteur ajoute'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping sensor card opens readings bottom sheet', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      mockInterceptor.addMockResponse('/api/v1/iot/sensors/s1/readings', data: [
        {'value': 64, 'unit': '%', 'recordedAt': '2026-03-13 10:00'},
        {'value': 63, 'unit': '%', 'recordedAt': '2026-03-13 09:00'},
      ]);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Capteur salon'));
      await tester.pumpAndSettle();

      expect(find.text('64 %'), findsWidgets);
      expect(find.text('63 %'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('readings bottom sheet shows empty message when no readings',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      mockInterceptor.addMockResponse(
          '/api/v1/iot/sensors/s1/readings', data: <Map<String, dynamic>>[]);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Capteur salon'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune mesure'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('sensor without label shows type display', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addSensors();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Second sensor has no label, so shows sensorTypeDisplay
      expect(find.text('Temperature'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('empty house list results in empty state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses',
          data: <Map<String, dynamic>>[]);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucun capteur'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });
}
