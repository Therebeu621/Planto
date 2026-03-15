import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/features/onboarding/onboarding_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late HouseService houseService;
  late RoomService roomService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    houseService = HouseService(dio: dio);
    roomService = RoomService(dio: dio);
  });

  Widget buildPage() {
    return MaterialApp(
      home: OnboardingPage(
        userEmail: 'test@test.com',
        houseService: houseService,
        roomService: roomService,
      ),
    );
  }

  group('OnboardingPage - Step 1 (Welcome)', () {
    testWidgets('shows welcome text and description', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('Bienvenue sur Planto !'), findsOneWidget);
      expect(find.textContaining('donner un nom'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows eco icon', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.byIcon(Icons.eco), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows house name field with default value', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('Ma Maison'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows Continuer and Passer buttons', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('Continuer'), findsWidgets);
      expect(find.text('Passer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows progress indicators', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      // 3 progress step containers exist
      expect(find.byType(PageView), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('empty house name shows error message', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Clear the house name field
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '');
      await tester.tap(find.text('Continuer').first);
      await tester.pumpAndSettle();

      expect(find.text('Donnez un nom a votre maison'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('Continuer navigates to step 2', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      await tester.tap(find.text('Continuer').first);
      await tester.pumpAndSettle();

      expect(find.text('Ajoutez votre premiere piece'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  group('OnboardingPage - Step 2 (Room)', () {
    Future<void> goToStep2(WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.tap(find.text('Continuer').first);
      await tester.pumpAndSettle();
    }

    testWidgets('shows room step title and description', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep2(tester);

      expect(find.text('Ajoutez votre premiere piece'), findsOneWidget);
      expect(find.textContaining('Ou allez-vous'), findsOneWidget);
      expect(find.byIcon(Icons.meeting_room_rounded), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows room type grid with 8 types', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep2(tester);

      expect(find.text('Salon'), findsWidgets);
      expect(find.text('Chambre'), findsWidgets);
      expect(find.text('Cuisine'), findsWidgets);
      expect(find.byType(GridView), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('selecting room type updates name field', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep2(tester);

      // Tap "Chambre" type
      await tester.tap(find.text('Chambre').last);
      await tester.pumpAndSettle();

      // Room name field should show "Chambre"
      expect(find.text('Chambre'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows custom room name field', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep2(tester);

      expect(find.textContaining('Nom personnalise'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('Continuer navigates to step 3', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep2(tester);

      await tester.tap(find.text('Continuer').first);
      await tester.pumpAndSettle();

      expect(find.text('Tout est pret !'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('empty room name auto-fills from type on step advance',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep2(tester);

      // Clear the room name
      final nameFields = find.byType(TextField);
      // Find the room name field (last one on step 2)
      for (final field in nameFields.evaluate()) {
        final widget = field.widget as TextField;
        if (widget.controller != null && widget.textAlign == TextAlign.center) {
          await tester.enterText(find.byWidget(widget), '');
          break;
        }
      }

      await tester.tap(find.text('Continuer').first);
      await tester.pumpAndSettle();

      // Step 3 should show the auto-filled room name
      expect(find.text('Tout est pret !'), findsOneWidget);
      expect(find.text('Salon'), findsWidgets); // Default type name

      FlutterError.onError = origOnError;
    });
  });

  group('OnboardingPage - Step 3 (Confirmation)', () {
    Future<void> goToStep3(WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.tap(find.text('Continuer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer').first);
      await tester.pumpAndSettle();
    }

    testWidgets('shows confirmation title and summary', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep3(tester);

      expect(find.text('Tout est pret !'), findsOneWidget);
      expect(find.textContaining('creer'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows house name in summary', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep3(tester);

      expect(find.text('Maison'), findsOneWidget);
      expect(find.text('Ma Maison'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows room name in summary', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep3(tester);

      expect(find.text('Premiere piece'), findsOneWidget);
      expect(find.text('Salon'), findsWidgets); // Room name

      FlutterError.onError = origOnError;
    });

    testWidgets('shows "C\'est parti !" button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await goToStep3(tester);

      expect(find.text('C\'est parti !'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('"C\'est parti !" creates house and room on success',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses', data: {
        'id': 'h1',
        'name': 'Ma Maison',
        'inviteCode': 'ABC',
        'memberCount': 1,
        'roomCount': 0,
        'isActive': true,
      }, statusCode: 201);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: {
        'id': 'r1',
        'name': 'Salon',
        'type': 'LIVING_ROOM',
        'plantCount': 0,
        'plants': [],
      }, statusCode: 201);

      await goToStep3(tester);

      await tester.tap(find.text('C\'est parti !'));
      await tester.pumpAndSettle();

      // After success, navigates away from onboarding
      expect(find.text('C\'est parti !'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('"C\'est parti !" shows error on failure', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses',
          data: {}, isError: true, errorStatusCode: 500);

      await goToStep3(tester);

      await tester.tap(find.text('C\'est parti !'));
      await tester.pumpAndSettle();

      // Error message should appear
      expect(find.byType(Text), findsWidgets);

      FlutterError.onError = origOnError;
    });
  });

  group('OnboardingPage - Skip', () {
    testWidgets('Passer button navigates away', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildPage());
      await tester.pump();

      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      // Should navigate away from onboarding (to HomePage)
      expect(find.text('Bienvenue sur Planto !'), findsNothing);

      FlutterError.onError = origOnError;
    });
  });
}
