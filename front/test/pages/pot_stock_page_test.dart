import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/pot_service.dart';
import 'package:planto/features/pot/pot_stock_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late PotService potService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    potService = PotService(dio: dio);
  });

  void addPots({bool includeEmpty = false}) {
    mockInterceptor.addMockResponse('/api/v1/pots', data: [
      {
        'id': 'pot1',
        'diameterCm': 14.0,
        'quantity': 3,
        'label': 'Terre cuite',
      },
      {
        'id': 'pot2',
        'diameterCm': 20.0,
        'quantity': includeEmpty ? 0 : 1,
        'label': null,
      },
    ]);
  }

  void addEmptyPots() {
    mockInterceptor.addMockResponse('/api/v1/pots', data: <Map<String, dynamic>>[]);
  }

  Widget buildPage() {
    return MaterialApp(
      home: PotStockPage(potService: potService),
    );
  }

  group('PotStockPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows appbar with title', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Stock de pots'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows pot list with sizes and quantities', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Pot de 14 cm'), findsOneWidget);
      expect(find.text('x3'), findsOneWidget);
      expect(find.text('Terre cuite'), findsOneWidget);
      expect(find.text('Pot de 20 cm'), findsOneWidget);
      expect(find.text('x1'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows summary card with total and sizes', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // 3 + 1
      expect(find.text('Tailles'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 sizes with quantity > 0

      FlutterError.onError = origOnError;
    });

    testWidgets('shows summary with correct available sizes count',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots(includeEmpty: true);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Only 1 size with quantity > 0
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 3 + 0
      expect(find.text('Tailles'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // 1 size available

      FlutterError.onError = origOnError;
    });

    testWidgets('shows FAB to add pots', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('FAB opens add pot dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter des pots'), findsOneWidget);
      expect(find.text('Diametre (cm)'), findsOneWidget);
      expect(find.text('Quantite'), findsOneWidget);
      expect(find.text('Label (optionnel)'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog validation rejects empty diameter', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Clear default quantity and try submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('Requis'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog validation rejects invalid diameter', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Diametre (cm)'), '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('Diametre invalide'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog validation rejects invalid quantity', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Diametre (cm)'), '14');
      final quantityField = find.widgetWithText(TextFormField, 'Quantite');
      await tester.enterText(quantityField, '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('Quantite invalide'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog creates pot successfully', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      // Use a dedicated interceptor for this test
      final testInterceptor = MockDioInterceptor();
      final testDio = createMockDio(testInterceptor);
      final testPotService = PotService(dio: testDio);

      // First load returns pots (GET /api/v1/pots -> 200)
      testInterceptor.addMockResponse('/api/v1/pots', data: [
        {'id': 'pot1', 'diameterCm': 14.0, 'quantity': 3, 'label': 'Terre cuite'},
      ]);

      await tester.pumpWidget(MaterialApp(
        home: PotStockPage(potService: testPotService),
      ));
      await tester.pumpAndSettle();

      // Now switch mock to return 201 for POST
      testInterceptor.clearResponses();
      testInterceptor.addMockResponse('/api/v1/pots',
          data: {'id': 'pot3', 'diameterCm': 10.0, 'quantity': 2},
          statusCode: 201);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Diametre (cm)'), '10');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('Pots ajoutes au stock'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add dialog cancel closes', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Diametre (cm)'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping pot card opens edit quantity dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pot de 14 cm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Modifier la quantite'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('edit dialog updates quantity', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      mockInterceptor.addMockResponse('/api/v1/pots/pot1',
          data: {'id': 'pot1', 'diameterCm': 14.0, 'quantity': 5});

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pot de 14 cm'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, '5');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('edit dialog delete option deletes pot', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots();
      mockInterceptor.addMockResponse('/api/v1/pots/pot1', data: {});

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pot de 14 cm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows empty state with icon and button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addEmptyPots();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucun pot en stock'), findsOneWidget);
      expect(find.textContaining('Ajoutez vos pots'), findsOneWidget);
      expect(find.text('Ajouter des pots'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows error state with retry button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/pots',
          data: {}, isError: true, errorStatusCode: 500);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.textContaining('Erreur'), findsOneWidget);
      expect(find.text('Reessayer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('retry button on error state reloads', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/pots',
          data: {}, isError: true, errorStatusCode: 500);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      mockInterceptor.clearResponses();
      addPots();
      await tester.tap(find.text('Reessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Pot de 14 cm'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('pot with 0 quantity shows different border style',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPots(includeEmpty: true);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('x0'), findsOneWidget);
      expect(find.text('x3'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });
}
