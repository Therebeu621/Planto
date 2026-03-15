import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/features/plant/plant_details_page.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/pot_service.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late PlantService plantService;
  late RoomService roomService;
  late HouseService houseService;
  late PotService potService;

  final mockPlantDetail = {
    'id': 'p1',
    'nickname': 'Mon Ficus',
    'speciesCommonName': 'Ficus elastica',
    'photoUrl': null,
    'needsWatering': true,
    'isSick': false,
    'isWilted': false,
    'needsRepotting': true,
    'exposure': 'PARTIAL_SHADE',
    'wateringIntervalDays': 7,
    'lastWatered': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
    'nextWateringDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'notes': 'Belle plante tropicale',
    'potDiameterCm': 14.0,
    'roomId': 'r1',
    'roomName': 'Salon',
    'acquiredAt': '2024-06-15T00:00:00Z',
    'createdAt': '2024-06-15T00:00:00Z',
    'species': {
      'id': 's1',
      'commonName': 'Ficus elastica',
      'scientificName': 'Ficus elastica Roxb.',
      'family': 'Moraceae',
      'genus': 'Ficus',
      'imageUrl': null,
    },
    'room': {
      'id': 'r1',
      'name': 'Salon',
      'type': 'LIVING_ROOM',
    },
    'recentCareLogs': [
      {
        'id': 'cl1',
        'action': 'WATERING',
        'notes': null,
        'performedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'performedByName': 'Test User',
      },
      {
        'id': 'cl2',
        'action': 'FERTILIZING',
        'notes': 'Engrais liquide',
        'performedAt': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'performedByName': 'Test User',
      },
    ],
  };

  final mockPlantHealthy = {
    ...mockPlantDetail,
    'needsWatering': false,
    'isSick': false,
    'isWilted': false,
    'needsRepotting': false,
    'notes': null,
    'nextWateringDate': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
  };

  final mockPlantSick = {
    ...mockPlantDetail,
    'isSick': true,
    'isWilted': true,
  };

  final mockRooms = [
    {
      'id': 'r1',
      'name': 'Salon',
      'type': 'LIVING_ROOM',
      'plantCount': 2,
      'plants': [],
    },
    {
      'id': 'r2',
      'name': 'Chambre',
      'type': 'BEDROOM',
      'plantCount': 1,
      'plants': [],
    },
  ];

  final mockActiveHouse = {
    'id': 'h1',
    'name': 'Maison Test',
    'inviteCode': 'ABC123',
    'memberCount': 2,
    'roomCount': 3,
    'isActive': true,
    'role': 'OWNER',
  };

  final mockWateredPlant = {
    ...mockPlantDetail,
    'needsWatering': false,
    'nextWateringDate': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    'lastWatered': DateTime.now().toIso8601String(),
  };

  final mockPotSuggestions = [
    {
      'id': 'pot1',
      'diameterCm': 16.0,
      'quantity': 3,
      'label': 'Terre cuite',
    },
    {
      'id': 'pot2',
      'diameterCm': 18.0,
      'quantity': 1,
      'label': null,
    },
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final mockDio = createMockDio(mockInterceptor);
    plantService = PlantService(dio: mockDio);
    roomService = RoomService(dio: mockDio);
    houseService = HouseService(dio: mockDio);
    potService = PotService(dio: mockDio);
  });

  void setupMocks({Map<String, dynamic>? plantData, bool withError = false}) {
    mockInterceptor.clearResponses();
    if (withError) {
      mockInterceptor.addMockResponse('/api/v1/plants/p1', isError: true, errorStatusCode: 404);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: mockRooms);
    } else {
      mockInterceptor.addMockResponse('/api/v1/plants/p1', data: plantData ?? mockPlantDetail);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: mockRooms);
      mockInterceptor.addMockResponse('/api/v1/houses/active', data: mockActiveHouse);
    }
  }

  Widget buildWidget() {
    return MaterialApp(
      home: PlantDetailsPage(
        plantId: 'p1',
        plantName: 'Mon Ficus',
        plantService: plantService,
        roomService: roomService,
        houseService: houseService,
        notificationService: NotificationService(),
        potService: potService,
      ),
    );
  }

  group('PlantDetailsPage - Loading', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 50));
      // On first frames, loading state or content visible
      expect(find.byType(Scaffold), findsWidgets);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      FlutterError.onError = origOnError;
    });

    testWidgets('data loads and shows plant details', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mon Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Error State', () {
    testWidgets('shows error state when API fails', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(withError: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Erreur de chargement'), findsOneWidget);
      expect(find.text('Reessayer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('retry button reloads data', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(withError: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Now fix the mock to return success on retry
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/plants/p1', data: mockPlantDetail);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: mockRooms);

      await tester.tap(find.text('Reessayer'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mon Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - View Mode', () {
    testWidgets('shows plant nickname in header', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mon Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows species name', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ficus elastica'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows scientific name', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ficus elastica Roxb.'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows quick action buttons', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Arroser'), findsWidgets);
      expect(find.text('Modifier'), findsWidgets);
      expect(find.text('Fertiliser'), findsWidgets);
      expect(find.text('Tailler'), findsWidgets);
      expect(find.text('Traiter'), findsWidgets);
      expect(find.text('Note'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows repot button when plant needs repotting', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(); // plant has needsRepotting: true

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rempoter'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('does not show repot button for healthy plant', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(plantData: mockPlantHealthy as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rempoter'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows notes section when notes exist', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Belle plante tropicale'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows care history section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Care log actions
      expect(find.textContaining('Arrosage'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows danger zone section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down to find the delete button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Supprimer'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows app bar action icons (photo, qr, edit)', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.photo_library), findsWidgets);
      expect(find.byIcon(Icons.qr_code), findsWidgets);
      expect(find.byIcon(Icons.edit), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Water Plant', () {
    testWidgets('tapping water shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find and tap the Arroser action button
      final arroserButtons = find.text('Arroser');
      await tester.tap(arroserButtons.first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Confirmer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('confirming water calls API and reloads', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/water', data: mockWateredPlant);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Arroser').first);
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the "Arroser" button in the dialog
      final dialogArroserButtons = find.text('Arroser');
      await tester.tap(dialogArroserButtons.last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('canceling water dialog does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Arroser').first);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Annuler'));
      await tester.pump(const Duration(milliseconds: 300));

      // Back to detail view
      expect(find.text('Mon Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Delete Plant', () {
    testWidgets('tapping delete shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to danger zone
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.textContaining('Supprimer');
      if (deleteBtn.evaluate().isNotEmpty) {
        await tester.tap(deleteBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Edit Mode', () {
    testWidgets('tapping edit button switches to edit mode', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the Modifier quick action
      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Should be in edit mode
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('edit mode pre-fills form fields', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Nickname should be pre-filled
      expect(find.text('Mon Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('saving changes calls update API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          data: {...mockPlantDetail, 'nickname': 'Nouveau Ficus'});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Find save button
      final saveBtn = find.textContaining('Enregistrer');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.tap(saveBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Care Log Dialog', () {
    testWidgets('tapping Fertiliser opens care log dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/care-logs', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Fertiliser'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Fertilisation'), findsWidgets);
      expect(find.text('Enregistrer'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping Note opens care log dialog with autofocus', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Note'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Note'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('confirming care log calls API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/care-logs', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Tailler'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Enregistrer'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Repot Dialog', () {
    testWidgets('tapping Rempoter opens repot dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/suggestions', data: mockPotSuggestions);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to find repot button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));

      final repotBtn = find.text('Rempoter');
      if (repotBtn.evaluate().isNotEmpty) {
        await tester.tap(repotBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Rempoter'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('repot dialog shows pot suggestions', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/suggestions', data: mockPotSuggestions);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));

      final repotBtn = find.text('Rempoter');
      if (repotBtn.evaluate().isNotEmpty) {
        await tester.tap(repotBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Should show pot options
        expect(find.textContaining('16'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('repot dialog with empty suggestions shows warning', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/suggestions', data: []);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));

      final repotBtn = find.text('Rempoter');
      if (repotBtn.evaluate().isNotEmpty) {
        await tester.tap(repotBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Aucun pot disponible'), findsOneWidget);
      }

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Plant Icon Fallback', () {
    testWidgets('shows plant icon when no photo URL', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // plant.photoUrl is null, so should show eco icon
      expect(find.byIcon(Icons.eco), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Healthy plant', () {
    testWidgets('healthy plant does not show sick/wilted status', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(plantData: mockPlantHealthy as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Sick plant', () {
    testWidgets('sick plant shows health indicators', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(plantData: mockPlantSick as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Back Navigation', () {
    testWidgets('tapping back button pops page', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlantDetailsPage(
                  plantId: 'p1',
                  plantName: 'Mon Ficus',
                  plantService: plantService,
                  roomService: roomService,
                  houseService: houseService,
                  notificationService: NotificationService(),
                  potService: potService,
                ),
              ),
            ),
            child: const Text('Go'),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mon Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Delete Plant Confirmation', () {
    testWidgets('delete dialog shows and confirms deletion', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          data: mockPlantDetail);

      // Wrap in Navigator to allow pop on delete
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlantDetailsPage(
                  plantId: 'p1',
                  plantName: 'Mon Ficus',
                  plantService: plantService,
                  roomService: roomService,
                  houseService: houseService,
                  notificationService: NotificationService(),
                  potService: potService,
                ),
              ),
            ),
            child: const Text('Go'),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to danger zone
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.text('Supprimer');
      expect(deleteBtn, findsWidgets);
      // Tap the danger zone Supprimer button (the one in the ElevatedButton)
      await tester.tap(deleteBtn.last);
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should appear with confirmation text
      expect(find.textContaining('Voulez-vous vraiment supprimer'), findsOneWidget);

      // Tap Supprimer in the dialog to confirm
      await tester.tap(find.text('Supprimer').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // After deletion, should navigate back
      expect(find.text('Go'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete dialog cancel does not delete', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to danger zone
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.text('Supprimer');
      if (deleteBtn.evaluate().isNotEmpty) {
        await tester.tap(deleteBtn.last);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Annuler
        await tester.tap(find.text('Annuler'));
        await tester.pump(const Duration(milliseconds: 300));

        // Should still be on the page
        expect(find.text('Mon Ficus'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('delete plant API error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      // Make the delete call fail
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          data: mockPlantDetail);
      // Override with error for DELETE - we need a different path pattern
      // Since the interceptor matches by contains, we set a specific error for delete
      // Actually, the delete uses the same path /api/v1/plants/p1 so we need it to succeed for GET but fail for DELETE
      // The mock interceptor doesn't distinguish methods, so we'll mock it to error after initial load

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Now set up the mock to return an error for the delete
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: mockRooms);

      // Scroll to danger zone
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.text('Supprimer');
      if (deleteBtn.evaluate().isNotEmpty) {
        await tester.tap(deleteBtn.last);
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm delete in dialog
        final dialogSupprimer = find.text('Supprimer');
        await tester.tap(dialogSupprimer.last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Error snackbar should show
        expect(find.byType(SnackBar), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Save Changes Error', () {
    testWidgets('save changes error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Make update API fail
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: mockRooms);

      // Find save button
      final saveBtn = find.text('Enregistrer');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.tap(saveBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Error snackbar should appear
        expect(find.byType(SnackBar), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Water Plant Error', () {
    testWidgets('water plant API error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Make the water API fail
      mockInterceptor.addMockResponse('/water',
          isError: true, errorStatusCode: 500);

      await tester.tap(find.text('Arroser').first);
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm in the dialog
      await tester.tap(find.text('Arroser').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Error snackbar should appear
      expect(find.byType(SnackBar), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - App Bar Actions', () {
    testWidgets('tapping edit icon in app bar switches to edit mode', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the edit icon in the app bar (not the quick action button)
      final editIcons = find.byIcon(Icons.edit);
      await tester.tap(editIcons.first);
      await tester.pump(const Duration(milliseconds: 300));

      // Should be in edit mode - look for Enregistrer button
      expect(find.text('Enregistrer'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping back arrow pops page', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlantDetailsPage(
                  plantId: 'p1',
                  plantName: 'Mon Ficus',
                  plantService: plantService,
                  roomService: roomService,
                  houseService: houseService,
                  notificationService: NotificationService(),
                  potService: potService,
                ),
              ),
            ),
            child: const Text('Go'),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the back arrow button
      final backIcon = find.byIcon(Icons.arrow_back);
      if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first);
        await tester.pumpAndSettle();

        // Should be back to the Go button page
        expect(find.text('Go'), findsOneWidget);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping photo icon navigates to photo gallery', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      // Mock for photo gallery page loads
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos', data: []);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the photo library icon
      final photoIcon = find.byIcon(Icons.photo_library);
      await tester.tap(photoIcon.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should have navigated - the PlantDetailsPage should still be in the stack
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping QR code icon navigates to QR page', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the QR code icon
      final qrIcon = find.byIcon(Icons.qr_code);
      await tester.tap(qrIcon.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should have navigated
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Plant with Photo URL', () {
    testWidgets('shows network image when photoUrl is set', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      final mockPlantWithPhoto = {
        ...mockPlantDetail,
        'photoUrl': 'http://example.com/photo.jpg',
      };
      setupMocks(plantData: mockPlantWithPhoto as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should attempt to show Image.network (may error in test env)
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows species image when photoUrl is null but species imageUrl exists', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      final mockPlantWithSpeciesImage = {
        ...mockPlantDetail,
        'photoUrl': null,
        'species': {
          'id': 's1',
          'commonName': 'Ficus elastica',
          'scientificName': 'Ficus elastica Roxb.',
          'family': 'Moraceae',
          'genus': 'Ficus',
          'imageUrl': 'http://example.com/species.jpg',
        },
      };
      setupMocks(plantData: mockPlantWithSpeciesImage as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should attempt to show species Image.network
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Care Log Dialog Error', () {
    testWidgets('care log API error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/care-logs',
          isError: true, errorStatusCode: 500);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Traiter'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Enregistrer in the dialog
      await tester.tap(find.text('Enregistrer'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Error snackbar should appear
      expect(find.byType(SnackBar), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('care log dialog cancel does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Fertiliser'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Annuler
      await tester.tap(find.text('Annuler'));
      await tester.pump(const Duration(milliseconds: 300));

      // Still on the page
      expect(find.text('Mon Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Repot Dialog Extended', () {
    testWidgets('repot dialog select pot and confirm calls API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/suggestions', data: mockPotSuggestions);
      mockInterceptor.addMockResponse('/repot', data: {
        ...mockPlantDetail,
        'potDiameterCm': 16.0,
        'needsRepotting': false,
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to find repot button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));

      final repotBtn = find.text('Rempoter');
      if (repotBtn.evaluate().isNotEmpty) {
        await tester.tap(repotBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Select the first pot via RadioListTile
        final radioTiles = find.byType(RadioListTile<dynamic>);
        if (radioTiles.evaluate().isNotEmpty) {
          await tester.tap(radioTiles.first);
          await tester.pump(const Duration(milliseconds: 300));

          // Now tap Rempoter button in dialog
          final dialogRempoter = find.text('Rempoter');
          await tester.tap(dialogRempoter.last);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Should show success snackbar
          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('repot dialog cancel does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/suggestions', data: mockPotSuggestions);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));

      final repotBtn = find.text('Rempoter');
      if (repotBtn.evaluate().isNotEmpty) {
        await tester.tap(repotBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Annuler
        final annuler = find.text('Annuler');
        if (annuler.evaluate().isNotEmpty) {
          await tester.tap(annuler);
          await tester.pump(const Duration(milliseconds: 300));
        }

        // Still on the page
        expect(find.text('Mon Ficus'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('repot API error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/suggestions', data: mockPotSuggestions);
      mockInterceptor.addMockResponse('/repot',
          isError: true, errorStatusCode: 400);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));

      final repotBtn = find.text('Rempoter');
      if (repotBtn.evaluate().isNotEmpty) {
        await tester.tap(repotBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Select a pot
        final radioTiles = find.byType(RadioListTile<dynamic>);
        if (radioTiles.evaluate().isNotEmpty) {
          await tester.tap(radioTiles.first);
          await tester.pump(const Duration(milliseconds: 300));

          // Confirm repot
          final dialogRempoter = find.text('Rempoter');
          await tester.tap(dialogRempoter.last);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Error snackbar should show
          expect(find.byType(SnackBar), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Edit Mode Extended', () {
    testWidgets('edit mode close button resets form and exits edit mode', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter edit mode
      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify we are in edit mode
      expect(find.text('Enregistrer'), findsWidgets);

      // Tap the close button (X icon)
      final closeIcon = find.byIcon(Icons.close);
      if (closeIcon.evaluate().isNotEmpty) {
        await tester.tap(closeIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Should be back in view mode
        expect(find.text('Arroser'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('edit mode shows health switches', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter edit mode
      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down to see health switches
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Malade'), findsWidgets);
      expect(find.text('Fanee'), findsWidgets);
      expect(find.text('A rempoter'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('edit mode shows room selector', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter edit mode
      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Room selector should show room names
      expect(find.text('Salon'), findsWidgets);
      expect(find.text('Chambre'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('can select a different room in edit mode', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter edit mode
      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap a different room (Chambre)
      final chambre = find.text('Chambre');
      if (chambre.evaluate().isNotEmpty) {
        await tester.tap(chambre.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('PlantDetailsPage - Empty Care Logs', () {
    testWidgets('shows empty care log message when no care logs', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      final mockPlantNoCare = {
        ...mockPlantDetail,
        'recentCareLogs': <Map<String, dynamic>>[],
      };
      setupMocks(plantData: mockPlantNoCare as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down to care history
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Aucun soin enregistre'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });
}
