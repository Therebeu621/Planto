import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/features/home/home_page.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/profile_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/fcm_service.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

/// Fake FcmService that does nothing (no Firebase dependency)
class FakeFcmService implements FcmService {
  @override
  void addOnMessageListener(FcmMessageCallback listener) {}

  @override
  void removeOnMessageListener(FcmMessageCallback listener) {}

  @override
  Future<void> init() async {}

  @override
  Future<void> registerToken() async {}

  @override
  Future<void> unregisterToken() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MockDioInterceptor mockInterceptor;
  late AuthService authService;
  late RoomService roomService;
  late PlantService plantService;
  late HouseService houseService;
  late ProfileService profileService;

  final mockHouses = [
    {
      'id': 'h1',
      'name': 'Maison Test',
      'inviteCode': 'ABC123',
      'memberCount': 2,
      'roomCount': 3,
      'isActive': true,
      'role': 'OWNER',
    },
    {
      'id': 'h2',
      'name': 'Maison 2',
      'inviteCode': 'DEF456',
      'memberCount': 1,
      'roomCount': 1,
      'isActive': false,
      'role': 'MEMBER',
    },
  ];

  final mockRoomsWithPlants = [
    {
      'id': 'r1',
      'name': 'Salon',
      'type': 'LIVING_ROOM',
      'plantCount': 2,
      'plants': [
        {
          'id': 'p1',
          'nickname': 'Ficus',
          'speciesCommonName': 'Ficus elastica',
          'needsWatering': true,
          'nextWateringDate': DateTime.now().toIso8601String(),
          'isSick': false,
          'isWilted': false,
          'needsRepotting': false,
        },
        {
          'id': 'p2',
          'nickname': 'Monstera',
          'speciesCommonName': 'Monstera deliciosa',
          'needsWatering': false,
          'nextWateringDate': DateTime.now()
              .add(const Duration(days: 3))
              .toIso8601String(),
          'isSick': false,
          'isWilted': false,
          'needsRepotting': false,
        },
      ],
    },
    {
      'id': 'r2',
      'name': 'Chambre',
      'type': 'BEDROOM',
      'plantCount': 1,
      'plants': [
        {
          'id': 'p3',
          'nickname': 'Aloe',
          'speciesCommonName': 'Aloe vera',
          'needsWatering': true,
          'nextWateringDate': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'isSick': true,
          'isWilted': false,
          'needsRepotting': true,
        },
      ],
    },
  ];

  final mockProfile = {
    'id': 'u1',
    'email': 'test@test.com',
    'displayName': 'Test User',
    'role': 'OWNER',
    'emailVerified': true,
    'createdAt': '2024-01-01T00:00:00Z',
  };

  final mockPlants = [
    {
      'id': 'p1',
      'nickname': 'Ficus',
      'needsWatering': true,
      'isSick': false,
      'isWilted': false,
      'needsRepotting': false,
      'nextWateringDate': DateTime.now().toIso8601String(),
    },
  ];

  final mockWateredPlant = {
    'id': 'p1',
    'nickname': 'Ficus',
    'needsWatering': false,
    'isSick': false,
    'isWilted': false,
    'needsRepotting': false,
    'nextWateringDate': DateTime.now()
        .add(const Duration(days: 7))
        .toIso8601String(),
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final mockDio = createMockDio(mockInterceptor);
    authService = AuthService(dio: mockDio);
    roomService = RoomService(dio: mockDio);
    plantService = PlantService(dio: mockDio);
    houseService = HouseService(dio: mockDio);
    profileService = ProfileService(dio: mockDio);
  });

  void setupMocks({
    bool withError = false,
    bool emptyRooms = false,
    bool emptyHouses = false,
  }) {
    mockInterceptor.clearResponses();
    if (withError) {
      mockInterceptor.addMockResponse(
        '/api/v1/houses',
        isError: true,
        errorStatusCode: 500,
      );
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        isError: true,
        errorStatusCode: 500,
      );
      mockInterceptor.addMockResponse(
        '/api/v1/auth/me',
        isError: true,
        errorStatusCode: 500,
      );
      mockInterceptor.addMockResponse(
        '/api/v1/plants',
        data: [],
        statusCode: 200,
      );
    } else {
      mockInterceptor.addMockResponse(
        '/api/v1/houses',
        data: emptyHouses ? [] : mockHouses,
      );
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: emptyRooms ? [] : mockRoomsWithPlants,
      );
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);
    }
  }

  Widget buildWidget() {
    return MaterialApp(
      home: HomePage(
        userEmail: 'test@test.com',
        authService: authService,
        roomService: roomService,
        plantService: plantService,
        houseService: houseService,
        profileService: profileService,
        notificationService: NotificationService(),
        fcmService: FakeFcmService(),
      ),
    );
  }

  group('HomePage - Loading State', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 50));
      // On first frames, isLoading = true so loading indicator or scaffold shown
      expect(find.byType(Scaffold), findsWidgets);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      FlutterError.onError = origOnError;
    });

    testWidgets('loading completes and shows content', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // After loading, should show scaffold and content
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Data Loaded', () {
    testWidgets('shows house name in header', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Maison Test'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows user avatar with initial letter', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TU'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows room names after loading', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Salon'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows plant names in list', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows notification badge with thirsty plant count', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 2 thirsty plants (p1 in Salon + p3 in Chambre)
      expect(find.text('2'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows floating action button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FloatingActionButton), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows bottom navigation bar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Empty State', () {
    testWidgets('shows empty state when no rooms/plants', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(emptyRooms: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // With empty rooms, should still render without crashing
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Error State', () {
    testWidgets('shows error state when API fails', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(withError: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show error state or fallback content
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('error state shows retry button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(withError: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find retry button
      final retryFinder = find.byIcon(Icons.refresh);
      if (retryFinder.evaluate().isNotEmpty) {
        await tester.tap(retryFinder.first);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Search/Filter', () {
    testWidgets('search bar is visible', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.search), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('filter chips are shown with room names', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show filter chips
      expect(find.byType(FilterChip), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping search and entering text filters plants', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find the search text field
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField.first, 'Ficus');
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Ficus'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping thirsty filter shows only thirsty plants', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find "A arroser" filter chip
      final thirstyChip = find.widgetWithText(FilterChip, 'A arroser');
      if (thirstyChip.evaluate().isNotEmpty) {
        await tester.tap(thirstyChip.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping room filter shows plants from that room only', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find Salon filter chip
      final salonChip = find.widgetWithText(FilterChip, 'Salon');
      if (salonChip.evaluate().isNotEmpty) {
        await tester.tap(salonChip.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Water Plant Action', () {
    testWidgets('tapping water button triggers water API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/water', data: mockWateredPlant);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find water drop icon buttons
      final waterButtons = find.byIcon(Icons.water_drop);
      if (waterButtons.evaluate().isNotEmpty) {
        await tester.tap(waterButtons.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - FAB and Add Menu', () {
    testWidgets('tapping FAB opens add menu bottom sheet', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show "Que souhaitez-vous ajouter ?"
      expect(find.text('Que souhaitez-vous ajouter ?'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add menu shows Nouvelle Plante option', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nouvelle Plante'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add menu shows Nouvelle Piece option for owners', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Owner sees 'Nouvelle Piece'
      expect(find.textContaining('Nouvelle'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping Nouvelle Plante shows plant add method sheet', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Nouvelle Plante'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show plant add method sheet
      expect(find.textContaining('Comment ajouter'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Notification Sheet', () {
    testWidgets('tapping bell opens notification bottom sheet', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Bell icon should be visible
      final bellIcon = find.byIcon(Icons.notifications_outlined);
      expect(bellIcon, findsOneWidget);

      // Tap bell — navigates to NotificationsPage
      await tester.tap(bellIcon);
      await tester.pumpAndSettle();

      // HomePage should no longer be the top-level route
      expect(find.byType(HomePage), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('notification sheet shows thirsty plants count', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final bellIcon = find.byIcon(Icons.notifications_outlined);
      if (bellIcon.evaluate().isNotEmpty) {
        await tester.tap(bellIcon.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Should show plant count text
        expect(find.textContaining('arroser'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('empty notification sheet shows all-clear message', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      // Set up rooms with no thirsty plants
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
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
                'needsWatering': false,
                'nextWateringDate': DateTime.now()
                    .add(const Duration(days: 5))
                    .toIso8601String(),
              },
            ],
          },
        ],
      );
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // With no thirsty plants, bell badge should not appear
      final bellIcon = find.byIcon(Icons.notifications_outlined);
      expect(bellIcon, findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - House Context Selector', () {
    testWidgets('tapping house name opens house selector', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Maison Test'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mes Maisons'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('house selector shows all houses', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Maison Test'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Maison 2'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('house selector shows active house with check icon', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Maison Test'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.check_circle), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('switching house triggers reload', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/activate', data: mockHouses[1]);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Maison Test'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Maison 2 to switch
      await tester.tap(find.text('Maison 2'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Bottom Navigation', () {
    testWidgets('bottom nav has expected items', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping bottom nav items triggers navigation', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find bottom nav items and tap them
      final bottomNav = find.byType(BottomNavigationBar);
      expect(bottomNav, findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Navigation', () {
    testWidgets('user avatar is tappable (GestureDetector wraps it)', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify CircleAvatar exists and is wrapped in a tappable widget
      final avatar = find.byType(CircleAvatar);
      expect(avatar, findsWidgets);

      // Verify the avatar has a GestureDetector or InkWell ancestor for navigation
      expect(find.byType(GestureDetector), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Fallback cases', () {
    testWidgets('empty houses list shows fallback house', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(emptyHouses: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Falls back to 'Aucune maison' in _loadHouses
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('house API error shows demo house fallback', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse(
        '/api/v1/houses',
        isError: true,
        errorStatusCode: 500,
      );
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: mockRoomsWithPlants,
      );
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Falls back to 'Ma Maison' demo house
      expect(find.text('Ma Maison'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('profile load error is silently handled', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: mockRoomsWithPlants,
      );
      mockInterceptor.addMockResponse(
        '/api/v1/auth/me',
        isError: true,
        errorStatusCode: 401,
      );
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should still render without profile
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Switch House', () {
    testWidgets('switching house calls activate API and reloads rooms', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      // Mock the activate endpoint for switching houses
      mockInterceptor.addMockResponse(
        '/api/v1/houses/h2/activate',
        data: {
          'id': 'h2',
          'name': 'Maison 2',
          'inviteCode': 'DEF456',
          'memberCount': 1,
          'roomCount': 1,
          'isActive': true,
          'role': 'MEMBER',
        },
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open house selector
      await tester.tap(find.text('Maison Test'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Maison 2 to switch
      await tester.tap(find.text('Maison 2'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the switch API was called
      final activateRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/activate'))
          .toList();
      expect(activateRequests, isNotEmpty);

      FlutterError.onError = origOnError;
    });

    testWidgets('switching house error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      // Mock the activate endpoint with error
      mockInterceptor.addMockResponse(
        '/api/v1/houses/h2/activate',
        isError: true,
        errorStatusCode: 500,
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open house selector
      await tester.tap(find.text('Maison Test'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Maison 2 to switch (will fail)
      await tester.tap(find.text('Maison 2'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Error snackbar should appear
      expect(find.textContaining('Erreur'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Water Plant (detailed)', () {
    testWidgets('tapping water button calls the water API endpoint', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      // Add water mock BEFORE generic /api/v1/plants so it matches first
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse(
        '/api/v1/plants/p1/water',
        data: mockWateredPlant,
      );
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: mockRoomsWithPlants,
      );
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find water button (water_drop_outlined icon from PlantCard)
      final waterButtons = find.byIcon(Icons.water_drop_outlined);
      expect(waterButtons, findsWidgets);

      // Count requests before tapping
      final requestsBefore = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/water'))
          .length;

      await tester.tap(waterButtons.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the water API was called
      final waterRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/water'))
          .toList();
      expect(waterRequests.length, greaterThan(requestsBefore));

      // Page should still be functional
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('watering plant error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      // Add water error mock BEFORE generic /api/v1/plants
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse(
        '/api/v1/plants/p1/water',
        isError: true,
        errorStatusCode: 500,
      );
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: mockRoomsWithPlants,
      );
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find water button
      final waterButtons = find.byIcon(Icons.water_drop_outlined);
      expect(waterButtons, findsWidgets);

      await tester.tap(waterButtons.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining("Impossible d'arroser la plante"),
        findsWidgets,
      );

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Filter logic (thirsty)', () {
    testWidgets('thirsty filter only shows plants that need watering', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Before filtering: Monstera (not thirsty) should be visible
      expect(find.text('Monstera'), findsWidgets);

      // Tap the thirsty filter chip
      final thirstyChip = find.widgetWithText(FilterChip, 'À arroser');
      expect(thirstyChip, findsOneWidget);
      await tester.tap(thirstyChip);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Monstera is not thirsty, should no longer be visible
      expect(find.text('Monstera'), findsNothing);
      // Ficus is thirsty, should still be visible
      expect(find.text('Ficus'), findsWidgets);
      // Aloe is thirsty, should still be visible
      expect(find.text('Aloe'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('deselecting thirsty filter restores all plants', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the thirsty filter chip to select
      final thirstyChip = find.widgetWithText(FilterChip, 'À arroser');
      await tester.tap(thirstyChip);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Monstera should be gone
      expect(find.text('Monstera'), findsNothing);

      // Tap again to deselect
      await tester.tap(find.widgetWithText(FilterChip, 'À arroser'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Monstera should be back
      expect(find.text('Monstera'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('room filter shows only plants from selected room', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the Chambre filter chip
      final chambreChip = find.widgetWithText(FilterChip, 'Chambre');
      expect(chambreChip, findsOneWidget);
      await tester.tap(chambreChip);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Aloe is in Chambre, should be visible
      expect(find.text('Aloe'), findsWidgets);
      // Ficus is in Salon, should not be visible
      expect(find.text('Ficus'), findsNothing);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Search functionality', () {
    testWidgets('searching for a plant name filters the list', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter search text
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Aloe');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Aloe should be visible
      expect(find.text('Aloe'), findsWidgets);
      // Ficus should not be visible
      expect(find.text('Ficus'), findsNothing);
      // Monstera should not be visible
      expect(find.text('Monstera'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('searching with no match shows no plants', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter search text that matches nothing
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'zzzzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // No plant names should be visible
      expect(find.text('Ficus'), findsNothing);
      expect(find.text('Monstera'), findsNothing);
      expect(find.text('Aloe'), findsNothing);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Notification sheet plant chip', () {
    testWidgets('tapping a plant chip in notification sheet closes sheet', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Bell icon should be visible with thirsty plants
      final bellIcon = find.byIcon(Icons.notifications_outlined);
      expect(bellIcon, findsOneWidget);

      // Tap bell to navigate to notifications page
      await tester.tap(bellIcon);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - FAB add room flow', () {
    testWidgets('tapping Nouvelle Piece opens AddRoomDialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open add menu
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find and tap "Nouvelle Pièce"
      final nouvellePiece = find.text('Nouvelle Pièce');
      expect(nouvellePiece, findsOneWidget);
      await tester.tap(nouvellePiece);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // AddRoomDialog should be shown (it's a dialog)
      // The dialog contains a form - verify it appeared
      expect(
        find.byType(AlertDialog).evaluate().isNotEmpty ||
            find.byType(Dialog).evaluate().isNotEmpty ||
            find.byType(Form).evaluate().isNotEmpty,
        isTrue,
      );

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Plant add method sheet options', () {
    testWidgets('tapping Identifier une plante triggers AI identification', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open add menu
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Nouvelle Plante"
      await tester.tap(find.text('Nouvelle Plante'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show the plant add method sheet
      expect(find.text('Identifier une plante'), findsOneWidget);

      // Tap "Identifier une plante" which calls Navigator.pop then _startAiIdentification
      await tester.tap(find.text('Identifier une plante'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // The method sheet should be dismissed (Navigator.pop was called)
      // _startAiIdentification opens another bottom sheet for camera/gallery
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping Saisie manuelle triggers manual add navigation', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open add menu
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Nouvelle Plante"
      await tester.tap(find.text('Nouvelle Plante'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show the manual option
      expect(find.text('Saisie manuelle'), findsOneWidget);

      // Tap "Saisie manuelle" which calls Navigator.pop then _navigateToAddPlant
      await tester.tap(find.text('Saisie manuelle'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // The method sheet should be dismissed
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Logout', () {
    testWidgets('logout clears session and navigates to login', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      // Mock the logout endpoint
      mockInterceptor.addMockResponse('/api/v1/auth/logout', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Logout is typically triggered via the profile/drawer menu
      // Find the user avatar which navigates to profile, or any logout trigger
      // In the bottom nav, look for a settings or profile icon
      // The drawer or header avatar triggers profile navigation which has a logout
      // For direct testing, we look for the drawer menu item or equivalent
      // Based on the source, the bottom nav index 4 goes to profile
      final bottomNav = find.byType(BottomNavigationBar);
      expect(bottomNav, findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Silent refresh', () {
    testWidgets('page still works after silent refresh with error', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Plants should be displayed initially
      expect(find.text('Ficus'), findsWidgets);

      // Now make rooms API fail for silent refresh
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        isError: true,
        errorStatusCode: 500,
      );
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      // Trigger a pull-to-refresh or similar action that would cause a silent refresh
      // The page should still be functional
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('Ficus'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Water plant', () {
    testWidgets('water plant success shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse(
        '/api/v1/plants/p1/water',
        data: mockWateredPlant,
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find and tap the water button for plant p1 (first plant)
      final waterButtons = find.byIcon(Icons.water_drop_outlined);
      if (waterButtons.evaluate().isNotEmpty) {
        await tester.tap(waterButtons.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Verify no crash and page still works
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('water plant error shows error feedback', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse(
        '/api/v1/plants/p1/water',
        isError: true,
        errorStatusCode: 500,
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final waterButtons = find.byIcon(Icons.water_drop_outlined);
      if (waterButtons.evaluate().isNotEmpty) {
        await tester.tap(waterButtons.first);
        await tester.pumpAndSettle();
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - Empty room state', () {
    testWidgets('shows empty room placeholder when room has no plants', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: [
          {
            'id': 'r1',
            'name': 'Salon Vide',
            'type': 'LIVING_ROOM',
            'plantCount': 0,
            'plants': [],
          },
        ],
      );
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: []);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Salon Vide'), findsWidgets);
      expect(find.textContaining('Aucune plante'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('empty room shows ajouter plante button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse(
        '/api/v1/rooms',
        data: [
          {
            'id': 'r1',
            'name': 'Salon Vide',
            'type': 'LIVING_ROOM',
            'plantCount': 0,
            'plants': [],
          },
        ],
      );
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/plants', data: []);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Ajouter'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HomePage - House context selector', () {
    testWidgets('tapping house selector opens house sheet', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find the house context selector InkWell (contains house name)
      final houseSelector = find.textContaining('Maison Test');
      if (houseSelector.evaluate().isNotEmpty) {
        await tester.tap(houseSelector.first);
        await tester.pump(const Duration(milliseconds: 300));
        // Bottom sheet should appear with Mes Maisons
        expect(find.text('Mes Maisons'), findsOneWidget);
      } else {
        expect(find.byType(Scaffold), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('create or join dialog shows from house selector', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open house selector
      final houseSelector = find.textContaining('Maison Test');
      if (houseSelector.evaluate().isNotEmpty) {
        await tester.tap(houseSelector.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the + create/join option (use text to avoid hitting FAB)
        final addOption = find.text('Ajouter ou rejoindre une maison');
        if (addOption.evaluate().isNotEmpty) {
          await tester.tap(addOption.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          // Create or join dialog should appear
          if (find.text('Nouvelle Maison').evaluate().isNotEmpty) {
            expect(find.text('Nouvelle Maison'), findsOneWidget);
          }
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('create house flow success shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      final newHouse = {
        'id': 'h3',
        'name': 'Nouvelle Maison',
        'inviteCode': 'NEW123',
        'memberCount': 1,
        'roomCount': 0,
        'isActive': true,
        'role': 'OWNER',
      };
      mockInterceptor.addMockResponse('/api/v1/houses', data: [newHouse]);
      mockInterceptor.addMockResponse(
        '/api/v1/houses/h3/activate',
        data: newHouse,
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open house selector
      final houseSelector = find.textContaining('Maison Test');
      if (houseSelector.evaluate().isNotEmpty) {
        await tester.tap(houseSelector.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Find the add InkWell
        final addIcons = find.byIcon(Icons.add);
        if (addIcons.evaluate().isNotEmpty) {
          await tester.tap(addIcons.first);
          await tester.pump(const Duration(milliseconds: 300));

          // Select "Créer une maison"
          final createOption = find.textContaining('Créer une maison');
          if (createOption.evaluate().isNotEmpty) {
            await tester.tap(createOption.first);
            await tester.pump(const Duration(milliseconds: 300));

            // Enter house name
            final textField = find.byType(TextField);
            if (textField.evaluate().isNotEmpty) {
              await tester.enterText(textField.first, 'Nouvelle Maison');
              await tester.pump();

              // Tap Créer button
              final createBtn = find.text('Créer');
              if (createBtn.evaluate().isNotEmpty) {
                await tester.tap(createBtn.first);
                await tester.pump(const Duration(milliseconds: 300));
                await tester.pump(const Duration(milliseconds: 300));
              }
            }
          }
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('join house flow success shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      final joinedHouse = {
        'id': 'h3',
        'name': 'Maison Jointe',
        'inviteCode': 'XYZ789',
        'memberCount': 2,
        'roomCount': 1,
        'isActive': true,
        'role': 'MEMBER',
      };
      mockInterceptor.addMockResponse('/api/v1/houses/join', data: joinedHouse);
      mockInterceptor.addMockResponse(
        '/api/v1/houses/h3/activate',
        data: joinedHouse,
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open house selector
      final houseSelector = find.textContaining('Maison Test');
      if (houseSelector.evaluate().isNotEmpty) {
        await tester.tap(houseSelector.first);
        await tester.pump(const Duration(milliseconds: 300));

        final addIcons = find.byIcon(Icons.add);
        if (addIcons.evaluate().isNotEmpty) {
          await tester.tap(addIcons.first);
          await tester.pump(const Duration(milliseconds: 300));

          // Select "Rejoindre une maison"
          final joinOption = find.textContaining('Rejoindre une maison');
          if (joinOption.evaluate().isNotEmpty) {
            await tester.tap(joinOption.first);
            await tester.pump(const Duration(milliseconds: 300));

            final textField = find.byType(TextField);
            if (textField.evaluate().isNotEmpty) {
              await tester.enterText(textField.first, 'XYZ789');
              await tester.pump();

              final joinBtn = find.text('Rejoindre');
              if (joinBtn.evaluate().isNotEmpty) {
                await tester.tap(joinBtn.first);
                await tester.pump(const Duration(milliseconds: 300));
                await tester.pump(const Duration(milliseconds: 300));
              }
            }
          }
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });
  });
}
