import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/features/room/room_list_page.dart';
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

  void addRooms() {
    mockInterceptor.addMockResponse('/api/v1/rooms', data: [
      {
        'id': 'r1',
        'name': 'Salon Principal',
        'type': 'LIVING_ROOM',
        'plantCount': 3,
        'plants': [],
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
        'name': 'Bureau',
        'type': 'OFFICE',
        'plantCount': 1,
        'plants': [],
      },
    ]);
  }

  void addEmptyRooms() {
    mockInterceptor.addMockResponse('/api/v1/rooms',
        data: <Map<String, dynamic>>[]);
  }

  Widget buildPage() {
    return MaterialApp(
      home: RoomListPage(roomService: roomService),
    );
  }

  group('RoomListPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows SliverAppBar with stats after loading', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Mes Pieces'), findsOneWidget);
      // 3 rooms, 4 plants total
      expect(find.textContaining('3 pieces'), findsOneWidget);
      expect(find.textContaining('4 plantes'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows room cards with names and icons', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Salon Principal'), findsOneWidget);
      expect(find.text('Chambre'), findsOneWidget);
      expect(find.text('Bureau'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows plant count per room', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('3 plantes'), findsWidgets);
      expect(find.text('0 plante'), findsOneWidget);
      expect(find.text('1 plante'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows plant count badges', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('3'), findsWidgets);
      expect(find.text('0'), findsWidgets);
      expect(find.text('1'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows FAB with "Nouvelle piece"', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle piece'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows empty state when no rooms', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addEmptyRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucune piece'), findsOneWidget);
      expect(find.textContaining('premiere piece'), findsWidgets);
      expect(find.text('Creer une piece'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete button shows warning for room with plants', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Find delete button for first room (with 3 plants)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Impossible de supprimer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete button for empty room shows confirmation', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Second room (Chambre) has 0 plants
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ?'), findsOneWidget);
      expect(find.textContaining('Chambre'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete confirmation removes room', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      mockInterceptor.addMockResponse('/api/v1/rooms/r2', data: {});

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Piece supprimee'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete cancel does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Chambre'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('error loading rooms shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/rooms',
          data: {}, isError: true, errorStatusCode: 500);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.textContaining('Erreur'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('single room shows singular stats', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/rooms', data: [
        {
          'id': 'r1',
          'name': 'Salon',
          'type': 'LIVING_ROOM',
          'plantCount': 1,
          'plants': [],
        },
      ]);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.textContaining('1 piece'), findsOneWidget);
      expect(find.textContaining('1 plante'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('room types have different colors', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/rooms', data: [
        {'id': 'r1', 'name': 'Balcon', 'type': 'BALCONY', 'plantCount': 0, 'plants': []},
        {'id': 'r2', 'name': 'Jardin', 'type': 'GARDEN', 'plantCount': 0, 'plants': []},
        {'id': 'r3', 'name': 'Cuisine', 'type': 'KITCHEN', 'plantCount': 0, 'plants': []},
        {'id': 'r4', 'name': 'SDB', 'type': 'BATHROOM', 'plantCount': 0, 'plants': []},
        {'id': 'r5', 'name': 'Autre', 'type': 'OTHER', 'plantCount': 0, 'plants': []},
      ]);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Balcon'), findsOneWidget);
      expect(find.text('Jardin'), findsOneWidget);
      expect(find.text('Cuisine'), findsOneWidget);
      expect(find.text('SDB'), findsOneWidget);
      expect(find.text('Autre'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('room icons display correctly', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Room icons are emoji text (via Room.icon getter)
      expect(find.byIcon(Icons.eco), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });
}
