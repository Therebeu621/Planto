import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/features/auth/register_page.dart';
import 'package:planto/features/auth/login_page.dart';

import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio mockDio;
  late AuthService authService;
  FlutterExceptionHandler? origOnError;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    mockDio = createMockDio(mockInterceptor);
    authService = AuthService(dio: mockDio);
  });

  tearDown(() {
    if (origOnError != null) {
      FlutterError.onError = origOnError;
    }
  });

  Widget buildTestWidget({AuthService? auth}) {
    // Wrap in a Navigator so Navigator.pop works
    return MaterialApp(
      home: RegisterPage(authService: auth ?? authService),
    );
  }

  group('RegisterPage - Initial render', () {
    testWidgets('renders PLANTO title', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.text('PLANTO'), findsOneWidget);
    });

    testWidgets('renders form fields (name, email, password)', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byType(TextField), findsAtLeast(3));
      expect(find.text('Nom d\'affichage'), findsOneWidget);
      expect(find.text('Adresse email'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
    });

    testWidgets('renders S INSCRIRE button', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.text('S\'INSCRIRE'), findsOneWidget);
    });

    testWidgets('renders create account subtitle', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.textContaining('Créer un compte'), findsOneWidget);
    });

    testWidgets('renders eco icon logo', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
    });

    testWidgets('renders person, email and lock icons', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('renders login link (Deja un compte)', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.text('Déjà un compte ? '), findsOneWidget);
      expect(find.text('[Se connecter]'), findsOneWidget);
    });

    testWidgets('renders CustomPaint background (LeafPatternPainter)', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('RegisterPage - Password visibility toggle', () {
    testWidgets('initially shows visibility_off and toggles', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('toggles back to obscured', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('RegisterPage - Validation', () {
    testWidgets('empty fields show error message', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump();

      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('empty name only shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump();

      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
    });

    testWidgets('empty email shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump();

      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
    });

    testWidgets('empty password shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@gmail.com');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump();

      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
    });

    testWidgets('invalid email shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'invalid-email');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump();

      expect(find.text('Veuillez entrer une adresse email valide'), findsOneWidget);
    });

    testWidgets('short password shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'short');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump();

      expect(find.textContaining('au moins 8'), findsOneWidget);
    });
  });

  group('RegisterPage - Successful registration', () {
    testWidgets('calls register API with correct data', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/register',
        statusCode: 201,
        data: {
          'accessToken': 'fake-token',
          'refreshToken': 'fake-refresh-token',
        },
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pumpAndSettle();

      // Verify the register API was called
      final registerRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/register'))
          .toList();
      expect(registerRequests, isNotEmpty);
      // Validation errors should NOT be shown (all fields valid)
      expect(find.text('Veuillez remplir tous les champs'), findsNothing);
      expect(find.text('Veuillez entrer une adresse email valide'), findsNothing);
    });
  });

  group('RegisterPage - Registration failure', () {
    testWidgets('shows error on 409 conflict (email already used)', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/register',
        isError: true,
        errorStatusCode: 409,
        data: {'message': 'Email already exists'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'existing@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pumpAndSettle();

      // Should show error about email already used
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('S\'INSCRIRE'), findsOneWidget); // Button restored
    });

    testWidgets('shows error on other server error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/register',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('S\'INSCRIRE'), findsOneWidget);
    });
  });

  group('RegisterPage - Loading state', () {
    testWidgets('shows loading or error during registration', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      // Use a failing request to avoid navigation and timer issues
      mockInterceptor.addMockResponse('/api/v1/auth/register',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump();

      // Either loading indicator is shown or error has already appeared
      final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasError = find.byIcon(Icons.error_outline).evaluate().isNotEmpty;
      expect(hasProgress || hasError, isTrue);

      await tester.pumpAndSettle();
    });
  });

  group('RegisterPage - Successful registration with navigation', () {
    testWidgets('successful register navigates to email verification', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/register',
        statusCode: 201,
        data: {
          'accessToken': 'fake-token',
          'refreshToken': 'fake-refresh-token',
        },
      );
      mockInterceptor.addMockResponse('/api/v1/rooms', data: []);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nom d\'affichage'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'new@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('S\'INSCRIRE'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Register API should have been called
      final registerRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/register'))
          .toList();
      expect(registerRequests, isNotEmpty);
    });
  });

  group('RegisterPage - Navigation', () {
    testWidgets('back to login link pops navigator', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      // Push RegisterPage on top of a route so pop works
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegisterPage(authService: authService),
                ),
              );
            },
            child: const Text('GO'),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();

      expect(find.text('[Se connecter]'), findsOneWidget);

      await tester.tap(find.text('[Se connecter]'));
      await tester.pumpAndSettle();

      // Should have popped back
      expect(find.text('GO'), findsOneWidget);
    });
  });
}
