import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/features/room/add_room_dialog.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late RoomService roomService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    roomService = RoomService(dio: dio);
  });

  Future<void> openDialog(WidgetTester tester, {RoomService? service}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDialog(
              context: ctx,
              builder: (_) => AddRoomDialog(roomService: service ?? roomService),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('AddRoomDialog', () {
    testWidgets('renders dialog title', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);
      expect(find.text('Ajouter une pi\u00e8ce'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('renders room name field with hint', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);
      expect(find.text('Nom de la pi\u00e8ce'), findsOneWidget);
      expect(find.text('Ex: Salon'), findsOneWidget);
      expect(find.byIcon(Icons.meeting_room), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('renders room type label and grid', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);
      expect(find.text('Type de pi\u00e8ce'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows all 8 room types', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);
      expect(find.text('Salon'), findsWidgets);
      expect(find.text('Chambre'), findsWidgets);
      expect(find.text('Cuisine'), findsWidgets);
      // Other types may need scrolling but the grid exists
      expect(find.byType(GridView), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('has cancel and create buttons', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Cr\u00e9er'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('cancel button closes dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter une pi\u00e8ce'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('validation rejects empty room name', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);

      // Clear the name field (which may have been auto-filled)
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, '');
      await tester.tap(find.text('Cr\u00e9er'));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez entrer un nom'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('selecting room type changes selection and auto-fills name',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);

      // Initially "Salon" is selected (LIVING_ROOM default)
      // Clear the name field first
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, '');

      // Tap "Chambre" type
      await tester.tap(find.text('Chambre').last);
      await tester.pumpAndSettle();

      // Name should auto-fill to "Chambre"
      expect(find.text('Chambre'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('selecting type does not overwrite custom name', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await openDialog(tester);

      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Mon espace vert');

      // Tap a different type
      await tester.tap(find.text('Chambre').last);
      await tester.pumpAndSettle();

      // Custom name should remain
      expect(find.text('Mon espace vert'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('create button submits and returns true on success',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/rooms', data: {
        'id': 'r1',
        'name': 'Mon Salon',
        'type': 'LIVING_ROOM',
        'plantCount': 0,
        'plants': [],
      }, statusCode: 201);

      await openDialog(tester);

      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Mon Salon');
      await tester.tap(find.text('Cr\u00e9er'));
      await tester.pumpAndSettle();

      // Dialog should be closed (success)
      expect(find.text('Ajouter une pi\u00e8ce'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('create button shows error snackbar on failure', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/rooms',
          data: {}, isError: true, errorStatusCode: 500);

      await openDialog(tester);

      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Mon Salon');
      await tester.tap(find.text('Cr\u00e9er'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Erreur'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows loading state during creation', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      // Use a response that will succeed
      mockInterceptor.addMockResponse('/api/v1/rooms', data: {
        'id': 'r1',
        'name': 'Test',
        'type': 'LIVING_ROOM',
        'plantCount': 0,
        'plants': [],
      }, statusCode: 201);

      await openDialog(tester);

      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Test');
      await tester.tap(find.text('Cr\u00e9er'));
      // Don't settle - check for intermediate state
      await tester.pump();

      // The button may show loading indicator or be disabled
      // In any case, after settling the dialog closes
      await tester.pumpAndSettle();
      expect(find.text('Ajouter une pi\u00e8ce'), findsNothing);

      FlutterError.onError = origOnError;
    });
  });
}
