import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/stats_service.dart';
import 'package:planto/features/stats/stats_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late StatsService statsService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    statsService = StatsService(dio: dio);
  });

  void addFullDashboard() {
    mockInterceptor.addMockResponse('/api/v1/stats/dashboard', data: {
      'totalPlants': 15,
      'healthyPlants': 12,
      'needsWateringToday': 3,
      'sickPlants': 1,
      'level': 5,
      'levelName': 'Jardinier',
      'xp': 1250,
      'wateringStreak': 7,
      'badgesUnlocked': 4,
      'totalBadges': 12,
      'houseRankings': [
        {'rank': 1, 'userName': 'Alice', 'level': 5, 'levelName': 'Jardinier', 'xp': 1250},
        {'rank': 2, 'userName': 'Bob', 'level': 3, 'levelName': 'Pousse', 'xp': 800},
      ],
      'wateringsLast7Days': {
        'Lun': 3,
        'Mar': 1,
        'Mer': 2,
        'Jeu': 0,
        'Ven': 4,
        'Sam': 1,
        'Dim': 2,
      },
      'recentActivity': [
        {
          'type': 'WATERING',
          'userName': 'Alice',
          'description': 'a arrose',
          'plantName': 'Ficus',
          'timeAgo': 'il y a 2h',
        },
        {
          'type': 'FERTILIZING',
          'userName': 'Bob',
          'description': 'a fertilise',
          'plantName': 'Cactus',
          'timeAgo': 'hier',
        },
      ],
      'plantsByRoom': {
        'Salon': 5,
        'Chambre': 3,
        'Balcon': 7,
      },
    });
  }

  void addFullAnnualStats() {
    mockInterceptor.addMockResponse('/api/v1/stats/annual', data: {
      'totalWaterings': 365,
      'totalCareActions': 500,
      'plantsAdded': 10,
      'bestStreak': 30,
      'mostCaredPlant': 'Ficus',
      'mostCaredPlantActions': 120,
      'wateringsByMonth': {
        'Jan': 30,
        'Fev': 28,
        'Mar': 35,
      },
      'careActionsByType': {
        'WATERING': 365,
        'FERTILIZING': 50,
        'PRUNING': 20,
        'TREATMENT': 10,
        'REPOTTING': 5,
        'NOTE': 50,
      },
    });
  }

  void addMinimalData() {
    mockInterceptor.addMockResponse('/api/v1/stats/dashboard', data: {
      'totalPlants': 0,
      'healthyPlants': 0,
      'needsWateringToday': 0,
      'sickPlants': 0,
    });
    mockInterceptor.addMockResponse('/api/v1/stats/annual', data: {});
  }

  Widget buildPage() {
    return MaterialApp(
      home: StatsPage(statsService: statsService),
    );
  }

  group('StatsPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows appbar with title and tabs', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Statistiques'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Retrospective'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('dashboard tab shows stat cards', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Plantes'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('En forme'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('A arroser'), findsOneWidget);
      expect(find.text('Malades'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('dashboard shows gamification section', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Gamification'), findsOneWidget);
      expect(find.text('1250 XP'), findsWidgets);
      expect(find.textContaining('Streak: 7 jours'), findsOneWidget);
      expect(find.textContaining('Badges: 4/12'), findsOneWidget);
      expect(find.text('5'), findsWidgets); // Level number
      expect(find.text('Jardinier'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('dashboard shows house rankings', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Classement maison'), findsOneWidget);
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
      expect(find.text('1250 XP'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('dashboard shows waterings last 7 days bar chart', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Arrosages (7 derniers jours)'), findsOneWidget);
      expect(find.text('Lun'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('dashboard shows recent activity', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Activite recente'), findsOneWidget);
      expect(find.textContaining('Alice'), findsWidgets);
      expect(find.text('il y a 2h'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('dashboard shows plants by room', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Plantes par piece'), findsOneWidget);
      expect(find.text('Salon'), findsWidgets);
      expect(find.text('Balcon'), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('switching to Retrospective tab shows annual stats',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retrospective'));
      await tester.pumpAndSettle();

      expect(find.text('Arrosages'), findsWidgets);
      expect(find.text('365'), findsWidgets);
      expect(find.text('Soins'), findsWidgets);
      expect(find.text('500'), findsWidgets);
      expect(find.text('Plantes +'), findsOneWidget);
      expect(find.text('10'), findsWidgets);
      expect(find.text('Meilleur streak'), findsOneWidget);
      expect(find.text('30j'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('annual stats shows most cared plant', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retrospective'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ficus'), findsWidgets);
      expect(find.text('120 actions'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('annual stats shows year selector and navigation',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retrospective'));
      await tester.pumpAndSettle();

      final currentYear = DateTime.now().year.toString();
      expect(find.text(currentYear), findsOneWidget);

      // Tap previous year
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      final prevYear = (DateTime.now().year - 1).toString();
      expect(find.text(prevYear), findsOneWidget);

      // Tap next year
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text(currentYear), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('next year button disabled on current year', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retrospective'));
      await tester.pumpAndSettle();

      // Next year button should be disabled (onPressed is null)
      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(nextButton.onPressed, isNull);

      FlutterError.onError = origOnError;
    });

    testWidgets('annual stats shows waterings by month chart', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retrospective'));
      await tester.pumpAndSettle();

      expect(find.text('Arrosages par mois'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('annual stats shows care actions breakdown', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addFullDashboard();
      addFullAnnualStats();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retrospective'));
      await tester.pumpAndSettle();

      expect(find.text('Types de soins'), findsOneWidget);
      expect(find.text('Arrosages'), findsWidgets);
      expect(find.text('Fertilisations'), findsOneWidget);
      expect(find.text('Tailles'), findsOneWidget);
      expect(find.text('Traitements'), findsOneWidget);
      expect(find.text('Rempotages'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('empty annual stats shows "Pas de donnees" message',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMinimalData();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retrospective'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pas de donnees'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('minimal dashboard without optional sections', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMinimalData();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Plantes'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      // No rankings, no activity, no plants by room
      expect(find.text('Classement maison'), findsNothing);
      expect(find.text('Activite recente'), findsNothing);
      expect(find.text('Plantes par piece'), findsNothing);

      FlutterError.onError = origOnError;
    });
  });
}
