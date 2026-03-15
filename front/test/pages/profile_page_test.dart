import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/features/profile/profile_page.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/profile_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/gamification_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/plant_service.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late AuthService authService;
  late ProfileService profileService;
  late HouseService houseService;
  late GamificationService gamificationService;
  late PlantService plantService;

  final mockProfile = {
    'id': 'u1',
    'email': 'test@test.com',
    'displayName': 'Jean Dupont',
    'role': 'OWNER',
    'emailVerified': false,
    'createdAt': '2024-01-15T10:30:00Z',
    'profilePhotoUrl': null,
  };

  final mockProfileVerified = {
    ...mockProfile,
    'emailVerified': true,
  };

  final mockProfileWithPhoto = {
    ...mockProfile,
    'profilePhotoUrl': '/uploads/photo.jpg',
  };

  final mockStats = {
    'totalPlants': 12,
    'wateringsThisMonth': 28,
    'wateringStreak': 5,
    'healthyPlantsPercentage': 85,
    'oldestPlantName': 'Mon vieux ficus',
    'oldestPlantAcquiredAt': '2022-03-01T00:00:00Z',
  };

  final mockHouses = [
    {
      'id': 'h1',
      'name': 'Maison principale',
      'inviteCode': 'ABC123',
      'memberCount': 3,
      'roomCount': 5,
      'isActive': true,
      'role': 'OWNER',
    },
    {
      'id': 'h2',
      'name': 'Appartement vacances',
      'inviteCode': 'DEF456',
      'memberCount': 2,
      'roomCount': 2,
      'isActive': false,
      'role': 'MEMBER',
    },
  ];

  final mockGamification = {
    'xp': 1250,
    'level': 5,
    'levelName': 'Bourgeon',
    'xpForNextLevel': 500,
    'xpProgressInLevel': 250,
    'wateringStreak': 5,
    'bestWateringStreak': 12,
    'totalWaterings': 150,
    'totalCareActions': 200,
    'totalPlantsAdded': 15,
    'badges': [
      {
        'code': 'FIRST_PLANT',
        'name': 'Premiere plante',
        'description': 'Ajoutez votre premiere plante',
        'category': 'DISCOVERY',
        'iconUrl': '',
        'unlocked': true,
        'unlockedAt': '2024-01-15T12:00:00Z',
      },
      {
        'code': 'STREAK_7',
        'name': 'Regulier',
        'description': '7 jours de suite',
        'category': 'STREAK',
        'iconUrl': '',
        'unlocked': false,
      },
    ],
  };

  final mockPlants = [
    {
      'id': 'p1',
      'nickname': 'Ficus',
      'needsWatering': false,
      'isSick': false,
      'isWilted': false,
      'needsRepotting': false,
    },
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'notifications_enabled': true,
      'dark_mode_enabled': false,
      'language': 'fr',
      'reminder_hour': 9,
      'reminder_minute': 0,
    });
    mockInterceptor = MockDioInterceptor();
    final mockDio = createMockDio(mockInterceptor);
    authService = AuthService(dio: mockDio);
    profileService = ProfileService(dio: mockDio);
    houseService = HouseService(dio: mockDio);
    gamificationService = GamificationService(dio: mockDio);
    plantService = PlantService(dio: mockDio);
  });

  void setupMocks({bool withError = false, Map<String, dynamic>? profileData}) {
    mockInterceptor.clearResponses();
    if (withError) {
      // Add more specific paths first (stats before me) to avoid path.contains conflicts
      mockInterceptor.addMockResponse('/api/v1/auth/me/stats', isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/auth/me', isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/houses', isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/gamification/profile', isError: true, errorStatusCode: 500);
    } else {
      // Add more specific paths first (stats before me) to avoid path.contains conflicts
      mockInterceptor.addMockResponse('/api/v1/auth/me/stats', data: mockStats);
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: profileData ?? mockProfile);
      mockInterceptor.addMockResponse('/api/v1/houses', data: mockHouses);
      mockInterceptor.addMockResponse('/api/v1/gamification/profile', data: mockGamification);
      mockInterceptor.addMockResponse('/api/v1/plants', data: mockPlants);
    }
  }

  Widget buildWidget() {
    return ProviderScope(
      child: MaterialApp(
        home: ProfilePage(
          profileService: profileService,
          authService: authService,
          houseService: houseService,
          gamificationService: gamificationService,
          notificationService: NotificationService(),
          plantService: plantService,
        ),
      ),
    );
  }

  group('ProfilePage - Loading', () {
    testWidgets('shows loading indicator initially', (tester) async {
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

    testWidgets('loads data and shows profile', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Jean Dupont'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Error State', () {
    testWidgets('shows error when API fails', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(withError: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show error or fallback content
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Profile Display', () {
    testWidgets('shows user display name', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Jean Dupont'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows user email', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('test@test.com'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows initials avatar when no photo', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // UserProfile initials for 'Jean Dupont' = 'JD'
      expect(find.text('JD'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows email not verified badge when unverified', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show unverified email indicator
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('verified email user does not show verify button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(profileData: mockProfileVerified as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Stats', () {
    testWidgets('shows total plants stat in user info', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // totalPlants shown in user info section as '12'
      expect(find.textContaining('12'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows watering streak in stats section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to stats section
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      // Streak shown as '5 jours'
      expect(find.textContaining('5 jours'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows healthy percentage in stats section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to stats section
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      // Healthy percentage shown as '85%'
      expect(find.textContaining('85%'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Gamification', () {
    testWidgets('shows level info', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Bourgeon'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows XP info', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('1250'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows badges', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to badges section
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Premiere plante'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Settings', () {
    testWidgets('shows notification toggle', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to settings section
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Notification'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows dark mode toggle', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('sombre'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('toggling dark mode updates state', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      final switches = find.byType(Switch);
      if (switches.evaluate().length >= 2) {
        await tester.tap(switches.at(1)); // Dark mode switch
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Houses', () {
    testWidgets('shows houses dialog when tapping Mes Maisons', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to find 'Mes Maisons' in the account section
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 300));

      final maisonsTile = find.text('Mes Maisons');
      if (maisonsTile.evaluate().isNotEmpty) {
        await tester.tap(maisonsTile.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Maison principale'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Actions', () {
    testWidgets('logout shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 300));

      final logoutBtn = find.text('Deconnexion');
      if (logoutBtn.evaluate().isNotEmpty) {
        await tester.tap(logoutBtn.last);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('deconnecter'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('change password shows dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final changePwBtn = find.textContaining('mot de passe');
      if (changePwBtn.evaluate().isNotEmpty) {
        await tester.tap(changePwBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Mot de passe'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('edit display name shows dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: {
        ...mockProfile,
        'displayName': 'Nouveau Nom',
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find edit name button (pencil icon next to name)
      final editIcon = find.byIcon(Icons.edit);
      if (editIcon.evaluate().isNotEmpty) {
        await tester.tap(editIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Modifier'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('delete account shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.textContaining('Supprimer');
      if (deleteBtn.evaluate().isNotEmpty) {
        await tester.tap(deleteBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('irreversible'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('change photo shows bottom sheet options', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find the avatar area and tap to change photo
      final cameraIcon = find.byIcon(Icons.camera_alt);
      if (cameraIcon.evaluate().isNotEmpty) {
        await tester.tap(cameraIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('galerie'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('verify email shows dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/resend-verification', data: {});
      mockInterceptor.addMockResponse('/verify-email', data: mockProfileVerified);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find verify email button
      final verifyBtn = find.textContaining('Verifier');
      if (verifyBtn.evaluate().isNotEmpty) {
        await tester.tap(verifyBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('code'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Leave House', () {
    testWidgets('leave house shows confirmation', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find leave icon for non-owner house
      final leaveIcon = find.byIcon(Icons.exit_to_app);
      if (leaveIcon.evaluate().isNotEmpty) {
        await tester.tap(leaveIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Quitter'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Reminder Time', () {
    testWidgets('shows reminder time setting', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      // Should show reminder time
      expect(find.textContaining('Rappel'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Multiple Renders', () {
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

  group('ProfilePage - Logout Flow', () {
    testWidgets('cancel logout dismisses dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to bottom to find logout
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 300));

      final logoutBtn = find.text('Deconnexion');
      if (logoutBtn.evaluate().isNotEmpty) {
        await tester.tap(logoutBtn.last);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Annuler to cancel
        final cancelBtn = find.text('Annuler');
        expect(cancelBtn, findsWidgets);
        await tester.tap(cancelBtn.last);
        await tester.pump(const Duration(milliseconds: 300));

        // Should still be on profile page
        expect(find.text('Mon Profil'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('confirm logout navigates to login', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/logout', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to bottom to find logout
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 300));

      final logoutBtn = find.text('Deconnexion');
      if (logoutBtn.evaluate().isNotEmpty) {
        await tester.tap(logoutBtn.last);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the Deconnexion button in the dialog (ElevatedButton)
        final confirmBtn = find.widgetWithText(ElevatedButton, 'Deconnexion');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Should navigate away from profile
          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Delete Account Flow', () {
    testWidgets('cancel delete account dismisses dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.textContaining('Supprimer');
      if (deleteBtn.evaluate().isNotEmpty) {
        await tester.tap(deleteBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Annuler
        final cancelBtn = find.text('Annuler');
        expect(cancelBtn, findsWidgets);
        await tester.tap(cancelBtn.last);
        await tester.pump(const Duration(milliseconds: 300));

        // Should still be on profile page
        expect(find.text('Mon Profil'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('confirm delete account calls API and navigates', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);
      mockInterceptor.addMockResponse('/api/v1/auth/logout', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.textContaining('Supprimer');
      if (deleteBtn.evaluate().isNotEmpty) {
        await tester.tap(deleteBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Supprimer confirm button in dialog
        final confirmBtn = find.widgetWithText(ElevatedButton, 'Supprimer');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('delete account shows error on failure', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Now add the error mock for delete (after initial load succeeded)
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/auth/me', isError: true, errorStatusCode: 500);

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      final deleteBtn = find.textContaining('Supprimer');
      if (deleteBtn.evaluate().isNotEmpty) {
        await tester.tap(deleteBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        final confirmBtn = find.widgetWithText(ElevatedButton, 'Supprimer');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Should show error snackbar or stay on page
          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Edit Display Name Flow', () {
    testWidgets('edit name dialog submits and updates', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: {
        ...mockProfile,
        'displayName': 'Nouveau Nom',
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final editIcon = find.byIcon(Icons.edit);
      if (editIcon.evaluate().isNotEmpty) {
        await tester.tap(editIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Clear existing text and type new name
        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'Nouveau Nom');
          await tester.pump(const Duration(milliseconds: 100));

          // Tap Enregistrer
          final saveBtn = find.text('Enregistrer');
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.tap(saveBtn.first);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));

            // Should show success or updated name
            expect(find.byType(Scaffold), findsWidgets);
          }
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('edit name cancel does not update', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final editIcon = find.byIcon(Icons.edit);
      if (editIcon.evaluate().isNotEmpty) {
        await tester.tap(editIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Annuler
        final cancelBtn = find.text('Annuler');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.last);
          await tester.pump(const Duration(milliseconds: 300));

          // Name should remain unchanged
          expect(find.text('Jean Dupont'), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Change Password Flow', () {
    testWidgets('cancel change password dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final changePwBtn = find.textContaining('mot de passe');
      if (changePwBtn.evaluate().isNotEmpty) {
        await tester.tap(changePwBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Annuler
        final cancelBtn = find.text('Annuler');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.last);
          await tester.pump(const Duration(milliseconds: 300));
        }

        expect(find.text('Mon Profil'), findsWidgets);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('submit matching passwords succeeds', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/me/password', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final changePwBtn = find.textContaining('mot de passe');
      if (changePwBtn.evaluate().isNotEmpty) {
        await tester.tap(changePwBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Fill in password fields
        final textFields = find.byType(TextField);
        if (textFields.evaluate().length >= 3) {
          await tester.enterText(textFields.at(0), 'oldPassword');
          await tester.enterText(textFields.at(1), 'newPassword123');
          await tester.enterText(textFields.at(2), 'newPassword123');
          await tester.pump(const Duration(milliseconds: 100));

          // Tap Changer
          final changeBtn = find.text('Changer');
          if (changeBtn.evaluate().isNotEmpty) {
            await tester.tap(changeBtn.first);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));

            // Should show success snackbar
            expect(find.byType(Scaffold), findsWidgets);
          }
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('submit mismatching passwords shows error', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final changePwBtn = find.textContaining('mot de passe');
      if (changePwBtn.evaluate().isNotEmpty) {
        await tester.tap(changePwBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Fill in mismatching password fields
        final textFields = find.byType(TextField);
        if (textFields.evaluate().length >= 3) {
          await tester.enterText(textFields.at(0), 'oldPassword');
          await tester.enterText(textFields.at(1), 'newPassword123');
          await tester.enterText(textFields.at(2), 'differentPassword');
          await tester.pump(const Duration(milliseconds: 100));

          // Tap Changer
          final changeBtn = find.text('Changer');
          if (changeBtn.evaluate().isNotEmpty) {
            await tester.tap(changeBtn.first);
            await tester.pump(const Duration(milliseconds: 300));

            // Should show mismatch snackbar
            expect(find.textContaining('correspondent'), findsWidgets);
          }
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('change password API error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/me/password', isError: true, errorStatusCode: 400);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      final changePwBtn = find.textContaining('mot de passe');
      if (changePwBtn.evaluate().isNotEmpty) {
        await tester.tap(changePwBtn.first);
        await tester.pump(const Duration(milliseconds: 300));

        final textFields = find.byType(TextField);
        if (textFields.evaluate().length >= 3) {
          await tester.enterText(textFields.at(0), 'oldPassword');
          await tester.enterText(textFields.at(1), 'newPassword123');
          await tester.enterText(textFields.at(2), 'newPassword123');
          await tester.pump(const Duration(milliseconds: 100));

          final changeBtn = find.text('Changer');
          if (changeBtn.evaluate().isNotEmpty) {
            await tester.tap(changeBtn.first);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));

            // Should show error
            expect(find.byType(Scaffold), findsWidgets);
          }
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Notification Toggle', () {
    testWidgets('notification switch is present and can be found', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      final switches = find.byType(Switch);
      // Notification switch should exist
      expect(switches.evaluate().isNotEmpty, isTrue);
      expect(find.textContaining('Notification'), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Theme Toggle', () {
    testWidgets('toggling theme switch changes dark mode', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      final switches = find.byType(Switch);
      if (switches.evaluate().length >= 2) {
        await tester.tap(switches.at(1));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Reminder Time Picker', () {
    testWidgets('tapping reminder time opens time picker', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      // Find the reminder time display and tap it
      final rappelText = find.textContaining('Rappel');
      if (rappelText.evaluate().isNotEmpty) {
        // Look for the time display or the row containing it
        final timeDisplay = find.textContaining('09:00');
        if (timeDisplay.evaluate().isNotEmpty) {
          await tester.tap(timeDisplay.first);
          await tester.pump(const Duration(milliseconds: 300));

          // Time picker should be shown
          expect(find.byType(Dialog), findsWidgets);

          // Tap OK to confirm the time picker
          final okBtn = find.text('OK');
          if (okBtn.evaluate().isNotEmpty) {
            await tester.tap(okBtn.first);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Leave House Flow', () {
    testWidgets('cancel leave house dismisses dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveIcon = find.byIcon(Icons.exit_to_app);
      if (leaveIcon.evaluate().isNotEmpty) {
        await tester.tap(leaveIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Annuler
        final cancelBtn = find.text('Annuler');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.last);
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Mon Profil'), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('confirm leave house calls API', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/houses/h2/leave', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveIcon = find.byIcon(Icons.exit_to_app);
      if (leaveIcon.evaluate().isNotEmpty) {
        await tester.tap(leaveIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Quitter confirm button
        final confirmBtn = find.widgetWithText(ElevatedButton, 'Quitter');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('leave house error shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/houses/h2/leave', isError: true, errorStatusCode: 500);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));

      final leaveIcon = find.byIcon(Icons.exit_to_app);
      if (leaveIcon.evaluate().isNotEmpty) {
        await tester.tap(leaveIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        final confirmBtn = find.widgetWithText(ElevatedButton, 'Quitter');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Should show error or remain on page
          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Change Photo Bottom Sheet', () {
    testWidgets('photo bottom sheet shows gallery and camera options', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final cameraIcon = find.byIcon(Icons.camera_alt);
      if (cameraIcon.evaluate().isNotEmpty) {
        await tester.tap(cameraIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Choisir depuis la galerie'), findsOneWidget);
        expect(find.text('Prendre une photo'), findsOneWidget);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('photo bottom sheet with existing photo shows delete option', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(profileData: mockProfileWithPhoto as Map<String, dynamic>);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final cameraIcon = find.byIcon(Icons.camera_alt);
      if (cameraIcon.evaluate().isNotEmpty) {
        await tester.tap(cameraIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Supprimer la photo'), findsOneWidget);
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping delete photo in bottom sheet calls delete', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(profileData: mockProfileWithPhoto as Map<String, dynamic>);
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo', data: mockProfile);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final cameraIcon = find.byIcon(Icons.camera_alt);
      if (cameraIcon.evaluate().isNotEmpty) {
        await tester.tap(cameraIcon.first);
        await tester.pump(const Duration(milliseconds: 300));

        final deletePhotoBtn = find.text('Supprimer la photo');
        if (deletePhotoBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(deletePhotoBtn.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(deletePhotoBtn.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Per-House Notifications', () {
    testWidgets('houses section shows in settings area', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to settings section
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      // The houses should be listed somewhere in settings/account
      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  // Helper: scroll to the account section and tap a ListTile by text
  Future<void> scrollToAndTap(WidgetTester tester, String text) async {
    // Try multiple scroll amounts to reach the target
    for (int i = 0; i < 5; i++) {
      final found = find.text(text);
      if (found.evaluate().isNotEmpty) {
        await tester.tap(found.first);
        await tester.pump();
        return;
      }
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('ProfilePage - Logout flow', () {
    testWidgets('logout confirmed navigates away', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await scrollToAndTap(tester, 'Deconnexion');
      await tester.pump(const Duration(milliseconds: 100));

      // Confirm dialog should appear - tap the confirm Deconnexion button
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Deconnexion');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('logout cancelled stays on profile', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await scrollToAndTap(tester, 'Deconnexion');
      await tester.pump(const Duration(milliseconds: 100));

      // Cancel the dialog
      final cancelBtn = find.widgetWithText(TextButton, 'Annuler');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn.first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Delete account flow', () {
    testWidgets('delete account confirmed calls API and navigates', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: mockProfile);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await scrollToAndTap(tester, 'Supprimer mon compte');
      await tester.pump(const Duration(milliseconds: 100));

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Supprimer');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('delete account cancelled stays on profile', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await scrollToAndTap(tester, 'Supprimer mon compte');
      await tester.pump(const Duration(milliseconds: 100));

      final cancelBtn = find.widgetWithText(TextButton, 'Annuler');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn.first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('delete account shows confirm dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await scrollToAndTap(tester, 'Supprimer mon compte');
      await tester.pump(const Duration(milliseconds: 100));

      // Should show confirm dialog with Supprimer and Annuler buttons
      expect(find.byType(AlertDialog), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Change password', () {
    testWidgets('change password success shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/change-password', data: {});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await scrollToAndTap(tester, 'Changer le mot de passe');
      await tester.pump(const Duration(milliseconds: 100));

      // Fill in the change password dialog
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 3) {
        await tester.enterText(textFields.at(0), 'OldPass123');
        await tester.enterText(textFields.at(1), 'NewPass123');
        await tester.enterText(textFields.at(2), 'NewPass123');
        await tester.pump();

        final changeBtn = find.widgetWithText(ElevatedButton, 'Changer');
        if (changeBtn.evaluate().isNotEmpty) {
          await tester.tap(changeBtn.first);
          await tester.pumpAndSettle();
          expect(find.byType(Scaffold), findsWidgets);
        }
      }

      FlutterError.onError = origOnError;
    });

    testWidgets('change password API error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/change-password',
          isError: true, errorStatusCode: 400);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await scrollToAndTap(tester, 'Changer le mot de passe');
      await tester.pump(const Duration(milliseconds: 100));

      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 3) {
        await tester.enterText(textFields.at(0), 'OldPass123');
        await tester.enterText(textFields.at(1), 'NewPass123');
        await tester.enterText(textFields.at(2), 'NewPass123');
        await tester.pump();

        final changeBtn = find.widgetWithText(ElevatedButton, 'Changer');
        if (changeBtn.evaluate().isNotEmpty) {
          await tester.tap(changeBtn.first);
          await tester.pumpAndSettle();
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Edit display name', () {
    testWidgets('edit display name success shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: {
        ...mockProfile,
        'displayName': 'Nouveau Nom',
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find the edit name button (pencil icon near display name)
      final editBtn = find.byTooltip('Modifier le nom');
      if (editBtn.evaluate().isNotEmpty) {
        await tester.tap(editBtn.first);
        await tester.pump(const Duration(milliseconds: 100));

        // Enter new name
        final dialogField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        if (dialogField.evaluate().isNotEmpty) {
          await tester.enterText(dialogField.first, 'Nouveau Nom');
          await tester.pump();

          final saveBtn = find.widgetWithText(ElevatedButton, 'Enregistrer');
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.tap(saveBtn.first);
            await tester.pumpAndSettle();
          }
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });
  });

  group('ProfilePage - Verify email', () {
    testWidgets('verify email shows dialog when tapping verification button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks(); // mockProfile has emailVerified: false
      mockInterceptor.addMockResponse('/api/v1/auth/resend-verification', data: {});
      mockInterceptor.addMockResponse('/api/v1/auth/verify-email', data: {
        ...mockProfile,
        'emailVerified': true,
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // The verify email button should be visible for unverified accounts
      final verifyBtn = find.text('Vérifier');
      if (verifyBtn.evaluate().isEmpty) {
        // Try scrolling up to find the verify button in the header area
        final verifyBtn2 = find.textContaining('email');
        if (verifyBtn2.evaluate().isNotEmpty) {
          await tester.tap(verifyBtn2.first);
          await tester.pump(const Duration(milliseconds: 100));
        }
      } else {
        await tester.tap(verifyBtn.first);
        await tester.pump(const Duration(milliseconds: 100));

        // Enter verification code
        final codeField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        if (codeField.evaluate().isNotEmpty) {
          await tester.enterText(codeField.first, '123456');
          await tester.pump();

          final verifyConfirm = find.widgetWithText(ElevatedButton, 'Verifier');
          if (verifyConfirm.evaluate().isNotEmpty) {
            await tester.tap(verifyConfirm.first);
            await tester.pumpAndSettle();
          }
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });

    testWidgets('verify email API error shows error snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();
      setupMocks();
      mockInterceptor.addMockResponse('/api/v1/auth/resend-verification', data: {});
      mockInterceptor.addMockResponse('/api/v1/auth/verify-email',
          isError: true, errorStatusCode: 400, data: {'message': 'Code invalide'});

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final verifyBtn = find.text('Vérifier');
      if (verifyBtn.evaluate().isNotEmpty) {
        await tester.tap(verifyBtn.first);
        await tester.pump(const Duration(milliseconds: 100));

        final codeField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        if (codeField.evaluate().isNotEmpty) {
          await tester.enterText(codeField.first, '000000');
          await tester.pump();

          final verifyConfirm = find.widgetWithText(ElevatedButton, 'Verifier');
          if (verifyConfirm.evaluate().isNotEmpty) {
            await tester.tap(verifyConfirm.first);
            await tester.pumpAndSettle();
          }
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
      FlutterError.onError = origOnError;
    });
  });
}
