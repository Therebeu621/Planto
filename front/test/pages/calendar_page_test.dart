import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/features/calendar/calendar_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late RoomService roomService;
  late PlantService plantService;
  late HouseService houseService;

  final today = DateTime.now();
  final todayStr = today.toIso8601String().split('T')[0];
  final tomorrowStr = today
      .add(const Duration(days: 1))
      .toIso8601String()
      .split('T')[0];
  final yesterdayStr = today
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .split('T')[0];

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    roomService = RoomService(dio: dio);
    plantService = PlantService(dio: dio);
    houseService = HouseService(dio: dio);
  });

  void addRoomsWithPlants({
    String? nextWatering,
    bool needsWatering = false,
    String? speciesName,
  }) {
    mockInterceptor.addMockResponse(
      '/api/v1/rooms',
      data: [
        {
          'id': 'r1',
          'name': 'Salon',
          'type': 'LIVING_ROOM',
          'plantCount': 1,
          'plants': [
            {
              'id': 'p1',
              'nickname': 'Ficus',
              'speciesCommonName': speciesName ?? 'Ficus elastica',
              'needsWatering': needsWatering,
              'nextWateringDate': nextWatering,
            },
          ],
        },
      ],
    );
  }

  void addEmptyRooms() {
    mockInterceptor.addMockResponse(
      '/api/v1/rooms',
      data: [
        {
          'id': 'r1',
          'name': 'Salon',
          'type': 'LIVING_ROOM',
          'plantCount': 0,
          'plants': <Map<String, dynamic>>[],
        },
      ],
    );
  }

  Widget buildPage() {
    return MaterialApp(
      locale: const Locale('fr', 'FR'),
      home: CalendarPage(
        roomService: roomService,
        plantService: plantService,
        houseService: houseService,
        notificationService: NotificationService(),
      ),
    );
  }

  group('CalendarPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addEmptyRooms();
      await tester.pumpWidget(buildPage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows calendar and appbar after loading', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addEmptyRooms();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Calendrier'), findsOneWidget);
      // TableCalendar renders day headers like "lun."
      expect(find.text('lun.'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets(
      'shows "Aucun arrosage prevu ce jour" when no plants on selected day',
      (tester) async {
        setupPageTest(tester);
        addTearDown(() => tester.view.resetPhysicalSize());
        final origOnError = suppressOverflowErrors();

        addEmptyRooms();
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.text('Aucun arrosage prevu ce jour'), findsOneWidget);

        FlutterError.onError = origOnError;
      },
    );

    testWidgets('shows plants needing water today with today watering date', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: todayStr, needsWatering: true);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Ficus'), findsWidgets);
      expect(find.text('Ficus elastica'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows "Aujourd\'hui" label for today plants', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: todayStr);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aujourd\'hui'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows urgent watering section with today plants', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: todayStr, needsWatering: true);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('A arroser maintenant'), findsOneWidget);
      expect(find.text('Arroser'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows upcoming section with next 7 days waterings', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: tomorrowStr);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Prochains 7 jours'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows "Aucun arrosage prevu cette semaine" when no upcoming', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      // Plant with watering date far in the future
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: [
          {
            'id': 'r1',
            'name': 'Salon',
            'type': 'LIVING_ROOM',
            'plantCount': 1,
            'plants': [
              {
                'id': 'p1',
                'nickname': 'Cactus',
                'needsWatering': false,
                'nextWateringDate': '2030-01-01',
              },
            ],
          },
        ],
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucun arrosage prevu cette semaine'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows error state and retry button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: {},
        isError: true,
        errorStatusCode: 500,
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Reessayer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('retry button reloads data', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: {},
        isError: true,
        errorStatusCode: 500,
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Now replace with success
      mockInterceptor.clearResponses();
      addEmptyRooms();
      await tester.tap(find.text('Reessayer'));
      await tester.pumpAndSettle();

      // TableCalendar renders day headers like "lun."
      expect(find.text('lun.'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('water plant action shows success snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: todayStr, needsWatering: true);
      // Mock water plant
      mockInterceptor.addMockResponse(
        '/api/v1/plants/p1/water',
        data: {
          'id': 'p1',
          'nickname': 'Ficus',
          'needsWatering': false,
          'nextWateringDate': tomorrowStr,
        },
      );
      // Mock active house
      mockInterceptor.addMockResponse(
        '/api/v1/houses/active',
        data: {
          'id': 'h1',
          'name': 'Maison',
          'inviteCode': 'ABC',
          'memberCount': 1,
          'roomCount': 1,
          'isActive': true,
        },
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Find the water drop IconButton in the ListTile (not the Icon in urgent card)
      final waterButton = find.widgetWithIcon(IconButton, Icons.water_drop);
      expect(waterButton, findsWidgets);

      await tester.tap(waterButton.first);
      await tester.pumpAndSettle();

      expect(find.text('Ficus arrosee !'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('water plant error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: todayStr, needsWatering: true);
      mockInterceptor.addMockResponse(
        '/api/v1/plants/p1/water',
        data: {},
        isError: true,
        errorStatusCode: 500,
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final waterButton = find.widgetWithIcon(IconButton, Icons.water_drop);
      await tester.tap(waterButton.first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Impossible d'arroser la plante"),
        findsWidgets,
      );

      FlutterError.onError = origOnError;
    });

    testWidgets('shows overdue plant with "En retard" for past watering', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: yesterdayStr);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // The overdue section should show the urgent section
      // Plants needing water today includes overdue plants
      expect(find.text('A arroser maintenant'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('plant with no species shows "Espece inconnue"', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: [
          {
            'id': 'r1',
            'name': 'Salon',
            'type': 'LIVING_ROOM',
            'plantCount': 1,
            'plants': [
              {
                'id': 'p1',
                'nickname': 'Plante',
                'speciesCommonName': null,
                'needsWatering': true,
                'nextWateringDate': todayStr,
              },
            ],
          },
        ],
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Espece inconnue'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('plant count badge shows correct count', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addRoomsWithPlants(nextWatering: todayStr);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('1 plante'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('multiple plants shows plural count', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: [
          {
            'id': 'r1',
            'name': 'Salon',
            'type': 'LIVING_ROOM',
            'plantCount': 2,
            'plants': [
              {
                'id': 'p1',
                'nickname': 'Ficus',
                'needsWatering': true,
                'nextWateringDate': todayStr,
              },
              {
                'id': 'p2',
                'nickname': 'Cactus',
                'needsWatering': true,
                'nextWateringDate': todayStr,
              },
            ],
          },
        ],
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('2 plantes'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('plant with empty nickname shows P as avatar initial', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: [
          {
            'id': 'r1',
            'name': 'Salon',
            'type': 'LIVING_ROOM',
            'plantCount': 1,
            'plants': [
              {
                'id': 'p1',
                'nickname': '',
                'needsWatering': true,
                'nextWateringDate': todayStr,
              },
            ],
          },
        ],
      );
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('P'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets(
      'plant with null nextWateringDate and needsWatering shows in urgent',
      (tester) async {
        setupPageTest(tester);
        addTearDown(() => tester.view.resetPhysicalSize());
        final origOnError = suppressOverflowErrors();

        mockInterceptor.addMockResponse(
          '/api/v1/rooms',
          data: [
            {
              'id': 'r1',
              'name': 'Salon',
              'type': 'LIVING_ROOM',
              'plantCount': 1,
              'plants': [
                {
                  'id': 'p1',
                  'nickname': 'TestPlant',
                  'needsWatering': true,
                  'nextWateringDate': null,
                },
              ],
            },
          ],
        );
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.text('A arroser maintenant'), findsOneWidget);

        FlutterError.onError = origOnError;
      },
    );
  });
}
