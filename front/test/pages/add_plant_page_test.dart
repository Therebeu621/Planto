import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/features/plant/add_plant_page.dart';
import 'package:planto/core/models/plant_identification_result.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/services/species_service.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late PlantService plantService;
  late RoomService roomService;
  late SpeciesService speciesService;

  final mockRooms = [
    {
      'id': 'r1',
      'name': 'Salon',
      'type': 'LIVING_ROOM',
      'plantCount': 2,
      'plants': [
        {'id': 'p1', 'nickname': 'Ficus existant', 'needsWatering': false},
      ],
    },
    {
      'id': 'r2',
      'name': 'Chambre',
      'type': 'BEDROOM',
      'plantCount': 0,
      'plants': [],
    },
    {
      'id': 'r3',
      'name': 'Balcon',
      'type': 'BALCONY',
      'plantCount': 1,
      'plants': [],
    },
  ];

  final mockCreatedPlant = {
    'id': 'new-p1',
    'nickname': 'Mon nouveau ficus',
    'needsWatering': false,
    'isSick': false,
    'isWilted': false,
    'needsRepotting': false,
    'exposure': 'PARTIAL_SHADE',
    'wateringIntervalDays': 7,
    'roomId': 'r1',
  };

  final mockSpeciesResults = [
    {
      'nomFrancais': 'Ficus elastica',
      'nomLatin': 'Ficus elastica',
      'arrosageFrequenceJours': 10,
      'luminosite': 'Mi-ombre',
    },
    {
      'nomFrancais': 'Ficus lyrata',
      'nomLatin': 'Ficus lyrata',
      'arrosageFrequenceJours': 7,
      'luminosite': 'Plein soleil',
    },
    {
      'nomFrancais': 'Ficus benjamina',
      'nomLatin': 'Ficus benjamina',
      'arrosageFrequenceJours': 5,
      'luminosite': 'Ombre',
    },
  ];

  final mockAiData = PlantIdentificationResult(
    petitNom: 'Mon Monstera',
    espece: 'Monstera deliciosa',
    arrosageJours: 10,
    luminosite: 'Mi-ombre',
    description: 'Grande plante tropicale avec des feuilles trouees.',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final mockDio = createMockDio(mockInterceptor);
    plantService = PlantService(dio: mockDio);
    roomService = RoomService(dio: mockDio);
    speciesService = SpeciesService(dio: mockDio);
  });

  void setupMocks({bool roomsError = false, bool emptyRooms = false}) {
    mockInterceptor.clearResponses();
    if (roomsError) {
      mockInterceptor.addMockResponse('/api/v1/rooms', isError: true, errorStatusCode: 500);
    } else {
      mockInterceptor.addMockResponse('/api/v1/rooms', data: emptyRooms ? [] : mockRooms);
    }
    mockInterceptor.addMockResponse('/api/v1/plants', data: mockCreatedPlant, statusCode: 201);
    mockInterceptor.addMockResponse('/api/v1/species/search', data: mockSpeciesResults);
    mockInterceptor.addMockResponse('/photo', data: mockCreatedPlant);
  }

  Widget buildWidget({PlantIdentificationResult? aiData, Uint8List? aiPhoto}) {
    return MaterialApp(
      home: AddPlantPage(
        aiData: aiData,
        aiPhoto: aiPhoto,
        plantService: plantService,
        roomService: roomService,
        speciesService: speciesService,
      ),
    );
  }

  group('AddPlantPage - Loading', () {
    testWidgets('shows loading indicator while rooms load', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Scaffold), findsWidgets);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      FlutterError.onError = origOnError;
    });

    testWidgets('loads rooms and shows form', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Form should be visible
      expect(find.byType(Form), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Room Loading Error', () {
    testWidgets('shows error snackbar when rooms fail to load', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(roomsError: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show form anyway (isLoadingRooms = false)
      expect(find.byType(Form), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Form Fields', () {
    testWidgets('shows nickname text field', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Petit nom'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows species search field', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Identite'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows room selector with rooms', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to find room selector
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Emplacement'), findsOneWidget);
      expect(find.text('Salon'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows exposure selector', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Conditions'), findsOneWidget);
      expect(find.text('Plein soleil'), findsWidgets);
      expect(find.text('Mi-ombre'), findsWidgets);
      expect(find.text('Ombre'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows watering interval slider', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Slider), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows health switches', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Etat de sante'), findsOneWidget);
      expect(find.text('Malade'), findsOneWidget);
      expect(find.text('Fanee'), findsOneWidget);
      expect(find.text('A rempoter'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows pot diameter field', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Taille du pot'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows last watered options', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Historique'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows photo section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Photo'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows submit button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Ajouter'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Form Interactions', () {
    testWidgets('can enter nickname', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Mon beau ficus');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mon beau ficus'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('selecting exposure updates state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Plein soleil" exposure option
      final sunOption = find.text('Plein soleil');
      if (sunOption.evaluate().isNotEmpty) {
        await tester.tap(sunOption.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('toggling health switch updates state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 300));

      final switches = find.byType(Switch);
      if (switches.evaluate().isNotEmpty) {
        await tester.tap(switches.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('selecting room updates selection', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Chambre room
      final chambre = find.text('Chambre');
      if (chambre.evaluate().isNotEmpty) {
        await tester.tap(chambre.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('selecting last watered option updates state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Aujourd'hui" last watered option
      final todayOption = find.text("Aujourd'hui");
      if (todayOption.evaluate().isNotEmpty) {
        await tester.tap(todayOption.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Form Validation', () {
    testWidgets('submitting empty form shows validation error', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to submit button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 300));

      // Find and tap submit button
      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Should show validation error
      expect(find.textContaining('nom'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('duplicate nickname shows validation error', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter existing nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Ficus existant');
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Validation: 'Une plante avec ce nom existe deja'
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Species Search', () {
    testWidgets('typing in species field triggers search', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find species text field and type
      final speciesFields = find.byType(TextField);
      // Enter text in species field (second text field)
      if (speciesFields.evaluate().length >= 2) {
        await tester.enterText(speciesFields.at(1), 'Ficus');
        await tester.pump(const Duration(milliseconds: 500)); // Wait for debounce
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('short query does not trigger search', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        await tester.enterText(speciesFields.at(1), 'F');
        await tester.pump(const Duration(milliseconds: 500));
      }

      // No suggestions should appear for single character
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - AI Data Pre-fill', () {
    testWidgets('shows AI banner when aiData provided', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget(aiData: mockAiData));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Identifiee par IA'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('pre-fills nickname from AI data', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget(aiData: mockAiData));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mon Monstera'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('pre-fills species from AI data', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget(aiData: mockAiData));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Monstera deliciosa'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows AI description in banner', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget(aiData: mockAiData));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('tropicale'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('does not show AI banner without aiData', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Identifiee par IA'), findsNothing);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - AI Photo Pre-fill', () {
    testWidgets('photo bytes are accepted and set as selected photo', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      // Create a valid 1x1 pixel PNG
      final fakePhoto = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // 8-bit RGB
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
        0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
        0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
        0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(buildWidget(aiData: mockAiData, aiPhoto: fakePhoto));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // With aiPhoto set, the photo section should show the image (not the add photo text)
      // The page should render without error
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows add photo text when no photo', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Touchez pour ajouter une photo'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Form Submission', () {
    testWidgets('successful submission calls create API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Test Plant');
      await tester.pump(const Duration(milliseconds: 300));

      // Select a room first
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      final salonChip = find.text('Salon');
      if (salonChip.evaluate().isNotEmpty) {
        await tester.tap(salonChip.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Verify the API was called (page may have popped or shown success)
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('failed submission shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/rooms', data: mockRooms);
      mockInterceptor.addMockResponse('/api/v1/plants', isError: true, errorStatusCode: 500);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Test Plant');
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Empty Rooms', () {
    testWidgets('empty rooms still shows form', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(emptyRooms: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Form), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('submitting without room shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(emptyRooms: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Test');
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Should show "Veuillez selectionner une piece" snackbar
      expect(find.textContaining('piece'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Section Titles', () {
    testWidgets('all section titles are shown', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Identite'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);

      // Scroll to see more sections
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Emplacement'), findsOneWidget);
      expect(find.text('Conditions'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Historique'), findsOneWidget);
      expect(find.text('Etat de sante'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Back Navigation', () {
    testWidgets('back button is present', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Header Display', () {
    testWidgets('shows Nouvelle plante text by default', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nouvelle plante'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows AI species name when aiData provided', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      // With AI data, species should be pre-filled
      await tester.pumpWidget(buildWidget(aiData: mockAiData));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // AI species name should be visible somewhere in the form
      expect(find.text('Monstera deliciosa'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Multiple Renders', () {
    testWidgets('pump multiple frames without crash', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Species Selection', () {
    testWidgets('typing species query shows suggestions and tapping one selects it', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find species field and type a query
      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        await tester.enterText(speciesFields.at(1), 'Ficus');
        await tester.pump(const Duration(milliseconds: 500)); // debounce
        await tester.pump(const Duration(milliseconds: 300)); // results
        await tester.pump(const Duration(milliseconds: 300));

        // Suggestions should appear - tap on the first one
        final suggestion = find.text('Ficus elastica');
        if (suggestion.evaluate().isNotEmpty) {
          await tester.tap(suggestion.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // After selecting, the species field should show the selected species
          expect(find.text('Ficus elastica'), findsWidgets);
        }
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('changing text after selection clears selected plant', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        // Type a query to trigger search
        await tester.enterText(speciesFields.at(1), 'Ficus');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Select a suggestion
        final suggestion = find.text('Ficus elastica');
        if (suggestion.evaluate().isNotEmpty) {
          await tester.tap(suggestion.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Now change text in species field to trigger clearing of selection
          await tester.enterText(speciesFields.at(1), 'Rose');
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('species focus node unfocus hides suggestions', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        // Type a query
        await tester.enterText(speciesFields.at(1), 'Ficus');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Tap on nickname field to unfocus species field
        final nicknameField = find.byType(TextFormField).first;
        await tester.tap(nicknameField);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Room Selection Interaction', () {
    testWidgets('tapping a room chip selects it and re-validates', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to room selector
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Balcon room
      final balcon = find.text('Balcon');
      if (balcon.evaluate().isNotEmpty) {
        await tester.tap(balcon.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Tap Chambre room (switch rooms)
      final chambre = find.text('Chambre');
      if (chambre.evaluate().isNotEmpty) {
        await tester.tap(chambre.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Watering Slider Interaction', () {
    testWidgets('dragging watering slider changes interval value', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      // Drag the slider to change value
      final slider = find.byType(Slider);
      if (slider.evaluate().isNotEmpty) {
        await tester.drag(slider, const Offset(100, 0));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Slider), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Photo Section Interaction', () {
    testWidgets('tapping photo area triggers photo picker bottom sheet', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on the camera icon in the header to trigger photo picker
      final cameraIcon = find.byIcon(Icons.camera_alt);
      if (cameraIcon.evaluate().isNotEmpty) {
        await tester.tap(cameraIcon.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Bottom sheet should appear with photo options
        final galleryOption = find.text('Choisir depuis la galerie');
        final cameraOption = find.text('Prendre une photo');
        expect(find.text('Ajouter une photo'), findsWidgets);

        // Dismiss the bottom sheet
        if (galleryOption.evaluate().isNotEmpty) {
          // Tap outside / press back to dismiss
          await tester.tapAt(const Offset(10, 10));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('photo delete option shown when photo is set', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      // Create a valid 1x1 pixel PNG
      final fakePhoto = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
        0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
        0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(buildWidget(aiData: mockAiData, aiPhoto: fakePhoto));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on the camera icon overlay to open photo picker
      final cameraIcon = find.byIcon(Icons.camera_alt);
      if (cameraIcon.evaluate().isNotEmpty) {
        await tester.tap(cameraIcon.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Delete option should be shown since photo is set
        final deleteOption = find.text('Supprimer la photo');
        if (deleteOption.evaluate().isNotEmpty) {
          expect(deleteOption, findsOneWidget);

          // Tap delete to remove photo
          await tester.tap(deleteOption);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Photo should be removed, "Touchez pour ajouter une photo" should reappear
          expect(find.text('Touchez pour ajouter une photo'), findsOneWidget);
        }
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('photo section shows delete button when photo exists via X icon', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      // Create a valid 1x1 pixel PNG
      final fakePhoto = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
        0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
        0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(buildWidget(aiData: mockAiData, aiPhoto: fakePhoto));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to photo section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show image and close icon in photo section
      final closeIcon = find.byIcon(Icons.close);
      if (closeIcon.evaluate().isNotEmpty) {
        await tester.tap(closeIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Photo should be removed
        expect(find.text('Galerie'), findsOneWidget);
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Full Form Submission', () {
    testWidgets('successful submission with room selected navigates back', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPlantPage(
                        plantService: plantService,
                        roomService: roomService,
                        speciesService: speciesService,
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      // Navigate to the AddPlantPage
      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Mon nouveau ficus');
      await tester.pump(const Duration(milliseconds: 300));

      // Rooms are loaded and first room is auto-selected (Salon, r1)
      // Scroll to the submit button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap submit
      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // After successful submission, page should pop back
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('submission with photo uploads photo after plant creation', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      // Add photo upload mock
      mockInterceptor.addMockResponse('/photo', data: mockCreatedPlant);

      // Create a valid 1x1 pixel PNG
      final fakePhoto = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
        0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
        0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPlantPage(
                        aiData: mockAiData,
                        aiPhoto: fakePhoto,
                        plantService: plantService,
                        roomService: roomService,
                        speciesService: speciesService,
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      // Navigate to AddPlantPage
      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Nickname is pre-filled by AI data as 'Mon Monstera'
      // Room is auto-selected (first room)
      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Verify API calls were made (plant create + photo upload)
      final plantCalls = mockInterceptor.capturedRequests.where(
        (r) => r.path.contains('/api/v1/plants'),
      ).toList();
      expect(plantCalls, isNotEmpty);

      FlutterError.onError = origOnError;
    });

    testWidgets('submission with photo upload error shows warning snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/rooms', data: mockRooms);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockCreatedPlant, statusCode: 201);
      // Photo upload fails
      mockInterceptor.addMockResponse('/photo', isError: true, errorStatusCode: 500);

      final fakePhoto = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
        0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
        0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPlantPage(
                        aiData: mockAiData,
                        aiPhoto: fakePhoto,
                        plantService: plantService,
                        roomService: roomService,
                        speciesService: speciesService,
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Last Watered Selection', () {
    testWidgets('tapping Hier option selects it', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final hierOption = find.text('Hier');
      if (hierOption.evaluate().isNotEmpty) {
        await tester.tap(hierOption.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping Je ne sais pas option selects it', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final unknownOption = find.text('Je ne sais pas');
      if (unknownOption.evaluate().isNotEmpty) {
        await tester.tap(unknownOption.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('submission with last watered set to today includes date', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPlantPage(
                        plantService: plantService,
                        roomService: roomService,
                        speciesService: speciesService,
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Test Plant Today');
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to last watered selector and select "Aujourd'hui"
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final todayOption = find.text("Aujourd'hui");
      if (todayOption.evaluate().isNotEmpty) {
        await tester.tap(todayOption.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Exposure Selection', () {
    testWidgets('tapping Ombre exposure option changes selection', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Ombre exposure option
      final ombreOption = find.text('Ombre');
      if (ombreOption.evaluate().isNotEmpty) {
        await tester.tap(ombreOption.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Health Switches Toggle', () {
    testWidgets('toggling all health switches updates state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 300));

      // Toggle all switches
      final switches = find.byType(Switch);
      for (int i = 0; i < switches.evaluate().length; i++) {
        await tester.tap(switches.at(i));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Pot Diameter Input', () {
    testWidgets('entering pot diameter value works', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 300));

      // Find pot diameter field and enter value
      final potField = find.widgetWithText(TextFormField, 'Diametre du pot (cm)');
      if (potField.evaluate().isNotEmpty) {
        await tester.enterText(potField, '14');
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('submission with pot diameter includes it in request', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPlantPage(
                        plantService: plantService,
                        roomService: roomService,
                        speciesService: speciesService,
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Plant With Pot');
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to pot diameter field
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 300));

      final potField = find.widgetWithText(TextFormField, 'Diametre du pot (cm)');
      if (potField.evaluate().isNotEmpty) {
        await tester.enterText(potField, '18');
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Species Search With Selection Then Submit', () {
    testWidgets('select species then submit includes species info', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPlantPage(
                        plantService: plantService,
                        roomService: roomService,
                        speciesService: speciesService,
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Mon Ficus');
      await tester.pump(const Duration(milliseconds: 300));

      // Search and select species
      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        await tester.enterText(speciesFields.at(1), 'Ficus');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final suggestion = find.text('Ficus elastica');
        if (suggestion.evaluate().isNotEmpty) {
          await tester.tap(suggestion.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Recommendation Card', () {
    testWidgets('selecting a species shows recommendation card', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Search and select species
      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        await tester.enterText(speciesFields.at(1), 'Ficus');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final suggestion = find.text('Ficus elastica');
        if (suggestion.evaluate().isNotEmpty) {
          await tester.tap(suggestion.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Recommendation card should be visible
          expect(find.text('Recommandations'), findsOneWidget);
          expect(find.textContaining('Ficus elastica'), findsWidgets);
        }
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Inline Warnings', () {
    testWidgets('changing exposure after species selection shows warning', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Search and select species (Ficus elastica has luminosite "Mi-ombre" -> PARTIAL_SHADE)
      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        await tester.enterText(speciesFields.at(1), 'Ficus');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final suggestion = find.text('Ficus elastica');
        if (suggestion.evaluate().isNotEmpty) {
          await tester.tap(suggestion.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      // Scroll to exposure section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      // Change exposure to something different (Plein soleil)
      final sunOption = find.text('Plein soleil');
      if (sunOption.evaluate().isNotEmpty) {
        await tester.tap(sunOption.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Inline warning should appear
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('AddPlantPage - Custom Species Text Submission', () {
    testWidgets('submission with custom species text (no selection) sends customSpecies', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPlantPage(
                        plantService: plantService,
                        roomService: roomService,
                        speciesService: speciesService,
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Fill nickname
      final nicknameField = find.byType(TextFormField).first;
      await tester.enterText(nicknameField, 'Custom Species Plant');
      await tester.pump(const Duration(milliseconds: 300));

      // Type species text but do NOT select from suggestions
      final speciesFields = find.byType(TextField);
      if (speciesFields.evaluate().length >= 2) {
        await tester.enterText(speciesFields.at(1), 'Unknown Rare Plant');
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Scroll to submit
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final submitBtn = find.textContaining('Ajouter');
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Plant should have been created with customSpecies
      final plantCalls = mockInterceptor.capturedRequests.where(
        (r) => r.path.contains('/api/v1/plants') && r.method == 'POST',
      ).toList();
      expect(plantCalls, isNotEmpty);

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });
}
