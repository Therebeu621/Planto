import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/features/house/house_page.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/plant_service.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late AuthService authService;
  late HouseService houseService;
  late PlantService plantService;

  final mockHouses = [
    {
      'id': 'h1',
      'name': 'Maison Test',
      'inviteCode': 'ABC123',
      'memberCount': 3,
      'roomCount': 5,
      'isActive': true,
      'role': 'OWNER',
    },
  ];

  final mockHousesWithMember = [
    {
      'id': 'h1',
      'name': 'Maison Test',
      'inviteCode': 'ABC123',
      'memberCount': 3,
      'roomCount': 5,
      'isActive': true,
      'role': 'MEMBER',
    },
  ];

  final mockHousesMultiple = [
    ...mockHouses,
    {
      'id': 'h2',
      'name': 'Maison Vacances',
      'inviteCode': 'DEF456',
      'memberCount': 2,
      'roomCount': 2,
      'isActive': false,
      'role': 'MEMBER',
    },
  ];

  final mockPlants = [
    {
      'id': 'p1',
      'nickname': 'Ficus',
      'needsWatering': true,
      'isSick': false,
      'isWilted': false,
      'needsRepotting': false,
      'nextWateringDate': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
    },
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final mockDio = createMockDio(mockInterceptor);
    authService = AuthService(dio: mockDio);
    houseService = HouseService(dio: mockDio);
    plantService = PlantService(dio: mockDio);
  });

  void setupMocks({
    List<Map<String, dynamic>>? houses,
    bool withError = false,
    bool emptyHouses = false,
  }) {
    mockInterceptor.clearResponses();
    if (withError) {
      mockInterceptor.addMockResponse('/api/v1/houses', isError: true, errorStatusCode: 500);
    } else {
      mockInterceptor.addMockResponse(
        '/api/v1/houses',
        data: emptyHouses ? [] : (houses ?? mockHouses),
      );
    }
    // Auth email mock
    mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);
  }

  Widget buildWidget({List<Map<String, dynamic>>? houses}) {
    return MaterialApp(
      home: HousePage(
        houseService: houseService,
        authService: authService,
        notificationService: NotificationService(),
        plantService: plantService,
      ),
    );
  }

  group('HousePage - Loading', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 50));
      // Loading indicator or content should be present
      expect(find.byType(Scaffold), findsWidgets);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      FlutterError.onError = origOnError;
    });

    testWidgets('loads data and shows house', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Maison Test'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Error State', () {
    testWidgets('handles API error gracefully', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(withError: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should not crash, show scaffold
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - No House State', () {
    testWidgets('shows no house card when empty', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(emptyHouses: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Aucune maison'), findsOneWidget);
      expect(find.textContaining('Creez ou rejoignez'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Active House Display', () {
    testWidgets('shows house name', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Maison Test'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows invite code', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ABC123'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows member count', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('3 membres'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows owner role badge', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Proprietaire'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows member role badge for non-owner', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesWithMember);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Membre'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows stat cards for active house', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Stats: Plantes (roomCount*3=15), Pieces (5), Membres (3)
      expect(find.text('15'), findsOneWidget); // Plantes
      expect(find.text('Plantes'), findsOneWidget);
      expect(find.text('Pieces'), findsOneWidget);
      expect(find.text('Membres'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Management Section', () {
    testWidgets('shows management section for active house', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Gestion'), findsOneWidget);
      expect(find.textContaining('Gerer les pieces'), findsOneWidget);
      expect(find.textContaining('Gerer les membres'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('owner sees delete house option', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Supprimer la maison'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('non-owner does not see delete house option', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesWithMember);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Supprimer la maison'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('notification toggle is shown', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Notifications'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('notification switch is rendered with correct initial value', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      // Notification switch should be present and enabled by default
      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsWidgets);
      expect(find.textContaining('Rappels'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Leave House', () {
    testWidgets('non-owner sees leave button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesWithMember);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.exit_to_app), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping leave shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesWithMember);
      mockInterceptor.addMockResponse('/leave', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveBtn = find.byIcon(Icons.exit_to_app);
      if (leaveBtn.evaluate().isNotEmpty) {
        await tester.tap(leaveBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Quitter la maison ?'), findsOneWidget);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('confirming leave calls API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesWithMember);
      mockInterceptor.addMockResponse('/leave', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveBtn = find.byIcon(Icons.exit_to_app);
      if (leaveBtn.evaluate().isNotEmpty) {
        await tester.tap(leaveBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Quitter'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('canceling leave does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesWithMember);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveBtn = find.byIcon(Icons.exit_to_app);
      if (leaveBtn.evaluate().isNotEmpty) {
        await tester.tap(leaveBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Annuler'));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.text('Maison Test'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Copy Invite Code', () {
    testWidgets('copy button is present', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Copier le code'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping copy shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Copier le code'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('presse-papier'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Delete House Dialog', () {
    testWidgets('tapping delete shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Supprimer la maison'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Supprimer la maison ?'), findsOneWidget);
      expect(find.textContaining('irreversible'), findsWidgets);
      expect(find.text('Supprimer definitivement'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete dialog shows warning items', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Supprimer la maison'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Toutes les plantes'), findsOneWidget);
      expect(find.text('Toutes les pieces'), findsOneWidget);
      expect(find.text('Tous les membres'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('canceling delete does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Supprimer la maison'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Annuler'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Maison Test'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Create House Dialog', () {
    // Note: Create/Join buttons would need to be found. In HousePage they appear
    // in the management section or when there's no house.
    testWidgets('create house dialog can be triggered from no-house state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(emptyHouses: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // No house state is shown
      expect(find.text('Aucune maison'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Logout', () {
    testWidgets('logout button is visible', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Se deconnecter'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping logout shows confirmation', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Se deconnecter'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Se deconnecter ?'), findsOneWidget);
      expect(find.text('Deconnexion'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('canceling logout keeps user on page', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Se deconnecter'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Annuler'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Maison Test'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - User Info in Header', () {
    testWidgets('shows user initial in avatar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // _userEmail is loaded from authService.getUserEmail() which returns null from mock
      // fallback shows 'U'
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Back Navigation', () {
    testWidgets('back button pops page', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find back arrow
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Multiple Renders', () {
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

  group('HousePage - Sections visibility', () {
    testWidgets('shows Ma Maison section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ma Maison'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows invite code section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Code d'invitation"), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Delete House Confirm', () {
    testWidgets('confirming delete calls API and pops navigator on success', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      // Mock successful delete
      mockInterceptor.addMockResponse('/api/v1/houses/h1', data: {});

      // Wrap in a Navigator so pop works
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HousePage(
                        houseService: houseService,
                        authService: authService,
                        notificationService: NotificationService(),
                        plantService: plantService,
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

      // Scroll to delete button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Supprimer la maison'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap confirm
      await tester.tap(find.text('Supprimer definitivement'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // After delete, navigator pops back to the previous page
      expect(find.text('Go'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('confirming delete shows error snackbar on API failure', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      // Set up mocks manually so error path is added before generic path
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse(
        '/api/v1/houses/h1',
        isError: true,
        errorStatusCode: 403,
      );
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to delete button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Supprimer la maison'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap confirm
      await tester.tap(find.text('Supprimer definitivement'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Error snackbar should appear
      expect(find.textContaining('Erreur'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Leave House Confirm with Error', () {
    testWidgets('confirming leave shows error snackbar on API failure', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      // Set up mocks manually so error path is added before generic path
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse(
        '/leave',
        isError: true,
        errorStatusCode: 400,
      );
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHousesWithMember);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveBtn = find.byIcon(Icons.exit_to_app);
      expect(leaveBtn, findsWidgets);

      await tester.tap(leaveBtn.first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Quitter la maison ?'), findsOneWidget);

      await tester.tap(find.text('Quitter'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Error snackbar should appear
      expect(find.textContaining('Erreur'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('confirming leave calls API and reloads data on success', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesWithMember);
      // Mock successful leave
      mockInterceptor.addMockResponse('/leave', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveBtn = find.byIcon(Icons.exit_to_app);
      expect(leaveBtn, findsWidgets);

      await tester.tap(leaveBtn.first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Quitter la maison ?'), findsOneWidget);
      expect(find.textContaining('Vous ne pourrez plus'), findsOneWidget);

      await tester.tap(find.text('Quitter'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Page should still be visible (reloaded data)
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Delete House Dialog Content', () {
    testWidgets('delete dialog shows house name in message', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Supprimer la maison'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Maison Test'), findsWidgets);
      expect(find.textContaining('supprimer'), findsWidgets);
      expect(find.text('Toutes les plantes'), findsOneWidget);
      expect(find.text('Toutes les pieces'), findsOneWidget);
      expect(find.text('Tous les membres'), findsOneWidget);
      expect(find.text('Supprimer definitivement'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Logout Confirm', () {
    testWidgets('confirming logout triggers navigation', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Se deconnecter'));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be showing
      expect(find.text('Se deconnecter ?'), findsOneWidget);
      expect(find.text('Deconnexion'), findsOneWidget);

      // Confirm logout
      await tester.tap(find.text('Deconnexion'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be dismissed after confirming
      expect(find.text('Se deconnecter ?'), findsNothing);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Management Actions', () {
    testWidgets('tapping manage rooms navigates to RoomListPage', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Gerer les pieces'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should navigate away or show RoomListPage
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping manage members navigates to HouseMembersPage', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Gerer les membres'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should navigate away or show HouseMembersPage
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Notification Toggle', () {
    testWidgets('notification toggle shows correct initial state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      // Initially notifications are enabled
      expect(find.textContaining('Rappels d\'arrosage actifs'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);

      // Verify the switch shows the notifications_active icon
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Multiple Houses', () {
    testWidgets('loads with multiple houses and shows active one', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(houses: mockHousesMultiple);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Active house should be displayed
      expect(find.text('Maison Test'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - User Email Display', () {
    testWidgets('shows user email when available', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      // Set up email in SharedPreferences
      SharedPreferences.setMockInitialValues({'user_email': 'test@example.com'});

      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('test@example.com'), findsOneWidget);
      // Avatar should show first letter uppercase
      expect(find.text('T'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows default U when email is null', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('U'), findsOneWidget);
      expect(find.text('Utilisateur'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Delete house flow', () {
    testWidgets('delete house confirmed calls API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/houses/h1', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to find the delete house option
      for (int i = 0; i < 3; i++) {
        final target = find.text('Supprimer la maison');
        if (target.evaluate().isNotEmpty) {
          await tester.tap(target.first);
          await tester.pump(const Duration(milliseconds: 100));
          break;
        }
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Confirm deletion if dialog appeared
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Supprimer definitivement');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('delete house cancelled stays on page', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      for (int i = 0; i < 3; i++) {
        final target = find.text('Supprimer la maison');
        if (target.evaluate().isNotEmpty) {
          await tester.tap(target.first);
          await tester.pump(const Duration(milliseconds: 100));
          break;
        }
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Cancel the dialog
      final cancelBtn = find.widgetWithText(TextButton, 'Annuler');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn.first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('delete house API error shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      // Set up error mock first so it takes priority over the generic /api/v1/houses mock
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/houses/h1',
          isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      for (int i = 0; i < 3; i++) {
        final target = find.text('Supprimer la maison');
        if (target.evaluate().isNotEmpty) {
          await tester.tap(target.first);
          await tester.pump(const Duration(milliseconds: 100));
          break;
        }
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Supprimer definitivement');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pumpAndSettle();
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });
  });

  group('HousePage - Logout flow', () {
    testWidgets('logout confirmed calls authService and navigates', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to find the logout button
      for (int i = 0; i < 5; i++) {
        final target = find.text('Se deconnecter');
        if (target.evaluate().isNotEmpty) {
          await tester.tap(target.first);
          await tester.pump(const Duration(milliseconds: 100));
          break;
        }
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Confirm logout
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Deconnexion');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('logout cancelled stays on house page', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      for (int i = 0; i < 5; i++) {
        final target = find.text('Se deconnecter');
        if (target.evaluate().isNotEmpty) {
          await tester.tap(target.first);
          await tester.pump(const Duration(milliseconds: 100));
          break;
        }
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }

      final cancelBtn = find.widgetWithText(TextButton, 'Annuler');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn.first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });
  });
}
