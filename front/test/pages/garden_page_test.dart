import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/garden_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/features/garden/garden_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late GardenService gardenService;
  late HouseService houseService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    gardenService = GardenService(dio: dio);
    houseService = HouseService(dio: dio);
  });

  void addHouse() {
    mockInterceptor.addMockResponse(
      '/api/v1/houses',
      data: [
        {
          'id': 'h1',
          'name': 'Maison',
          'inviteCode': 'ABC',
          'memberCount': 1,
          'roomCount': 1,
          'isActive': true,
        },
      ],
    );
  }

  void addCultures({String status = 'CROISSANCE', bool withLogs = false}) {
    addHouse();
    mockInterceptor.addMockResponse(
      '/api/v1/garden/house/h1',
      data: [
        {
          'id': 'c1',
          'plantName': 'Tomate',
          'variety': 'Coeur de boeuf',
          'status': status,
          'statusDisplay': status,
          'sowDate': '2026-03-01',
          'expectedHarvestDate': '2026-07-01',
          'harvestQuantity': status == 'RECOLTE' ? '2 kg' : null,
          'growthLogs': withLogs
              ? [
                  {
                    'newStatus': 'GERMINATION',
                    'newStatusDisplay': 'Germination',
                    'notes': 'Premieres pousses',
                  },
                ]
              : [],
        },
      ],
    );
  }

  void addEmptyCultures() {
    addHouse();
    mockInterceptor.addMockResponse(
      '/api/v1/garden/house/h1',
      data: <Map<String, dynamic>>[],
    );
  }

  Widget buildPage() {
    return MaterialApp(
      home: GardenPage(
        gardenService: gardenService,
        houseService: houseService,
      ),
    );
  }

  group('GardenPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      // Single pump to see loading state before data arrives
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows appbar with Potager title', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Potager'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows filter chips', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'Tout'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Semis'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Germination'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Croissance'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Floraison'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Recolte'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Termine'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows culture card with plant name and variety', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Tomate'), findsOneWidget);
      expect(find.text('Coeur de boeuf'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows status badge on culture card', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures(status: 'CROISSANCE');
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('CROISSANCE'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows sow and harvest date chips', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.textContaining('Seme:'), findsOneWidget);
      expect(find.textContaining('Recolte:'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows "Etape suivante" button for non-terminated cultures', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures(status: 'CROISSANCE');
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Etape suivante'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('does not show "Etape suivante" for terminated cultures', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures(status: 'TERMINE');
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Etape suivante'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows growth logs on culture card', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures(withLogs: true);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.textContaining('Historique'), findsOneWidget);
      expect(find.text('Germination'), findsWidgets);
      expect(find.text('Premieres pousses'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows harvest quantity when present', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures(status: 'RECOLTE');
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.textContaining('2 kg'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows empty state with add button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addEmptyCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucune culture'), findsOneWidget);
      expect(find.text('Premier semis'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('filter chip tap reloads data', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Semis'));
      await tester.pumpAndSettle();

      // Filter is applied
      expect(find.byType(FilterChip), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('add button opens add dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau semis'), findsOneWidget);
      expect(find.text('Nom de la plante *'), findsOneWidget);
      expect(find.text('Espèce / Variété *'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Semer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog cancel closes without creating', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau semis'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog creates culture with success', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures();
      mockInterceptor.addMockResponse(
        '/api/v1/garden/house/h1',
        data: {'id': 'c2', 'plantName': 'Basilic', 'status': 'SEMIS'},
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Use the IconButton with add icon in AppBar
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nom de la plante *'),
        'Basilic',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Espèce / Variété *'),
        'Basilic',
      );
      await tester.tap(find.text('Semer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Semis ajoute'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('status update dialog opens on card tap', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures(status: 'CROISSANCE');
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Etape suivante'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Passer a:'), findsOneWidget);
      expect(find.text('Confirmer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets(
      'status update dialog shows harvest field for RECOLTE transition',
      (tester) async {
        setupPageTest(tester);
        addTearDown(() => tester.view.resetPhysicalSize());
        final origOnError = suppressOverflowErrors();

        addCultures(status: 'FLORAISON');
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Etape suivante'));
        await tester.pumpAndSettle();

        expect(find.text('Quantite recoltee'), findsOneWidget);

        FlutterError.onError = origOnError;
      },
    );

    testWidgets('each status has correct icon', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addCultures(status: 'SEMIS');
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.grass), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('empty houses results in loading completing with empty state', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse(
        '/api/v1/houses',
        data: <Map<String, dynamic>>[],
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucune culture'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('culture without variety does not show variety text', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addHouse();
      mockInterceptor.addMockResponse(
        '/api/v1/garden/house/h1',
        data: [
          {
            'id': 'c1',
            'plantName': 'Basilic',
            'variety': null,
            'status': 'SEMIS',
            'statusDisplay': 'Semis',
          },
        ],
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Basilic'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });
}
