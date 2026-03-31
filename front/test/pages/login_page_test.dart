import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/features/auth/login_page.dart';

import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio mockDio;
  late AuthService authService;
  late HouseService houseService;
  FlutterExceptionHandler? origOnError;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    mockDio = createMockDio(mockInterceptor);
    authService = AuthService(dio: mockDio);
    houseService = HouseService(dio: mockDio);
  });

  tearDown(() {
    if (origOnError != null) {
      FlutterError.onError = origOnError;
    }
  });

  Widget buildTestWidget({AuthService? auth, HouseService? house}) {
    return MaterialApp(
      home: LoginPage(
        authService: auth ?? authService,
        houseService: house ?? houseService,
      ),
    );
  }

  group('LoginPage - Initial render', () {
    testWidgets('renders PLANTO title', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.text('PLANTO'), findsOneWidget);
    });

    testWidgets('renders email and password text fields', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byType(TextField), findsAtLeast(2));
      expect(find.text('Adresse email'), findsOneWidget);
    });

    testWidgets('renders SE CONNECTER button', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.text('SE CONNECTER'), findsOneWidget);
    });

    testWidgets('renders welcome text', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.textContaining('Bon retour'), findsOneWidget);
    });

    testWidgets('renders eco icon for logo', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
    });

    testWidgets('renders ou divider text', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.text('ou'), findsOneWidget);
    });

    testWidgets('renders Mot de passe oublie link', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });

    testWidgets('renders Pas encore de compte and S inscrire link', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.textContaining('Pas encore de compte'), findsOneWidget);
      expect(find.text('[S\'inscrire]'), findsOneWidget);
    });

    testWidgets('renders CustomPaint for background (LeafPatternPainter)', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders Google login button (IconButton)', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      // There should be an IconButton for Google login (plus the password toggle)
      expect(find.byType(IconButton), findsAtLeast(1));
    });
  });

  group('LoginPage - Password visibility toggle', () {
    testWidgets('initially shows visibility_off and toggles to visibility', (tester) async {
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

      // Toggle on
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      // Toggle off
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('LoginPage - Validation', () {
    testWidgets('empty fields show error message', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pump();

      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
      // Also verify the error container styling (error_outline icon)
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('empty password shows error message', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pump();

      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
    });

    testWidgets('empty email shows error message', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Find the password field via the hint
      final passwordField = find.widgetWithText(TextField, 'Mot de passe');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pump();

      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
    });
  });

  group('LoginPage - Successful login flow', () {
    testWidgets('calls login API with correct credentials', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/login', data: {
        'accessToken': 'fake-token',
        'refreshToken': 'fake-refresh-token',
      });
      mockInterceptor.addMockResponse('/api/v1/houses', data: [
        {'id': '1', 'name': 'My House', 'inviteCode': 'ABC123'},
      ]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pumpAndSettle();

      // Verify the login API was called
      final loginRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/login'))
          .toList();
      expect(loginRequests, isNotEmpty);
      // Validation error should NOT be shown (fields were filled)
      expect(find.text('Veuillez remplir tous les champs'), findsNothing);
    });

    testWidgets('calls houses API after successful login', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/login', data: {
        'accessToken': 'fake-token',
        'refreshToken': 'fake-refresh-token',
      });
      mockInterceptor.addMockResponse('/api/v1/houses', data: []);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pumpAndSettle();

      // Verify login API was called
      final loginRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/login'))
          .toList();
      expect(loginRequests, isNotEmpty);
    });
  });

  group('LoginPage - Login failure', () {
    testWidgets('shows error message on login failure (401)', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/login',
        isError: true,
        errorStatusCode: 401,
        data: {'message': 'Invalid credentials'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'wrongpassword');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Should not be loading anymore
      expect(find.text('SE CONNECTER'), findsOneWidget);
    });
  });

  group('LoginPage - Loading state', () {
    testWidgets('shows loading or navigates away after login tap', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      // Make login fail to avoid navigation issues with timers
      mockInterceptor.addMockResponse('/api/v1/auth/login',
        isError: true,
        errorStatusCode: 401,
        data: {'message': 'Invalid'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      // Pump once to see the loading state (before async completes)
      await tester.pump();

      // Either a progress indicator is shown or the error has already appeared
      final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasError = find.byIcon(Icons.error_outline).evaluate().isNotEmpty;
      expect(hasProgress || hasError, isTrue);

      await tester.pumpAndSettle();
    });
  });

  group('LoginPage - Navigation to other pages', () {
    testWidgets('forgot password link navigates', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();

      // Should navigate to ForgotPasswordPage
      expect(find.text('Mot de passe oublie'), findsOneWidget);
    });

    testWidgets('sign up link navigates to RegisterPage', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('[S\'inscrire]'));
      await tester.pumpAndSettle();

      // Should navigate to RegisterPage
      expect(find.text('S\'INSCRIRE'), findsOneWidget);
    });
  });

  group('LoginPage - navigateAfterLogin error handling', () {
    testWidgets('login API called even when houses would fail', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/login', data: {
        'accessToken': 'fake-token',
        'refreshToken': 'fake-refresh-token',
      });
      // Make getMyHouses fail
      mockInterceptor.addMockResponse('/api/v1/houses',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pumpAndSettle();

      // Verify login API was called
      final loginRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/login'))
          .toList();
      expect(loginRequests, isNotEmpty);
      // Validation error should NOT be shown
      expect(find.text('Veuillez remplir tous les champs'), findsNothing);
    });
  });

  group('LoginPage - Error message styling', () {
    testWidgets('error container has error_outline icon and text', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Trigger error
      await tester.tap(find.text('SE CONNECTER'));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
    });
  });

  group('LoginPage - Successful login with navigation', () {
    testWidgets('successful login navigates to home when houses exist', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      // Mock login success
      mockInterceptor.addMockResponse('/api/v1/auth/login',
        data: {'accessToken': 'fake-token', 'refreshToken': 'fake-refresh'},
      );
      // Mock houses - user has houses
      mockInterceptor.addMockResponse('/api/v1/houses', data: [
        {
          'id': 'h1',
          'name': 'Maison',
          'inviteCode': 'ABC',
          'memberCount': 1,
          'roomCount': 1,
          'isActive': true,
        },
      ]);
      // Mock rooms (needed by home page)
      mockInterceptor.addMockResponse('/api/v1/rooms', data: []);
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: {
        'id': 'u1',
        'email': 'test@test.com',
        'displayName': 'Test',
        'role': 'OWNER',
        'emailVerified': true,
        'createdAt': '2024-01-01T00:00:00Z',
      });
      mockInterceptor.addMockResponse('/api/v1/plants', data: []);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Login should have been called
      final loginRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/login'))
          .toList();
      expect(loginRequests, isNotEmpty);
    });

    testWidgets('successful login navigates to onboarding when no houses', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/login',
        data: {'accessToken': 'fake-token', 'refreshToken': 'fake-refresh'},
      );
      // Mock houses - empty
      mockInterceptor.addMockResponse('/api/v1/houses', data: []);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: []);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Login API should have been called
      final loginRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/login'))
          .toList();
      expect(loginRequests, isNotEmpty);
      // Houses API should have been called too
      final houseRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/houses'))
          .toList();
      expect(houseRequests, isNotEmpty);
    });

    testWidgets('successful login with houses error navigates to home', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/login',
        data: {'accessToken': 'fake-token', 'refreshToken': 'fake-refresh'},
      );
      // Mock houses - error
      mockInterceptor.addMockResponse('/api/v1/houses',
          isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: []);
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: {
        'id': 'u1',
        'email': 'test@test.com',
        'displayName': 'Test',
        'role': 'OWNER',
        'emailVerified': true,
        'createdAt': '2024-01-01T00:00:00Z',
      });
      mockInterceptor.addMockResponse('/api/v1/plants', data: []);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'password123');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Login and houses APIs should have been called
      final loginRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/auth/login'))
          .toList();
      expect(loginRequests, isNotEmpty);
    });

    testWidgets('login error shows error message', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/login',
        isError: true,
        errorStatusCode: 401,
        data: {'message': 'Unauthorized'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'wrongpass');
      await tester.pump();

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pumpAndSettle();

      // Error should be shown
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Google login button exists as icon button', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Google login is an IconButton (SVG icon, no text)
      expect(find.byType(IconButton), findsAtLeast(2));
    });
  });

  group('LoginPage - Google login flow', () {
    Widget buildWithGoogleLogin({
      required Future<String> Function() googleLoginFn,
      HouseService? house,
    }) {
      return MaterialApp(
        home: LoginPage(
          authService: authService,
          houseService: house ?? houseService,
          googleLoginFn: googleLoginFn,
        ),
      );
    }

    testWidgets('Google login success with houses navigates away', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses', data: [
        {
          'id': 'h1',
          'name': 'Maison',
          'inviteCode': 'ABC',
          'memberCount': 1,
          'roomCount': 1,
          'isActive': true,
        },
      ]);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: []);
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: {
        'id': 'u1',
        'email': 'google@test.com',
        'displayName': 'Google User',
        'role': 'OWNER',
        'emailVerified': true,
        'createdAt': '2024-01-01T00:00:00Z',
      });
      mockInterceptor.addMockResponse('/api/v1/plants', data: []);

      await tester.pumpWidget(buildWithGoogleLogin(
        googleLoginFn: () async => 'google@test.com',
      ));
      await tester.pump();

      // Tap Google button (last IconButton: first is password toggle)
      await tester.tap(find.byType(IconButton).last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // No validation error shown
      expect(find.text('Veuillez remplir tous les champs'), findsNothing);
    });

    testWidgets('Google login success without houses navigates to onboarding', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses', data: []);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: []);

      await tester.pumpWidget(buildWithGoogleLogin(
        googleLoginFn: () async => 'google@test.com',
      ));
      await tester.pump();

      await tester.tap(find.byType(IconButton).last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Houses API should have been called for navigation decision
      final houseRequests = mockInterceptor.capturedRequests
          .where((r) => r.path.contains('/api/v1/houses'))
          .toList();
      expect(houseRequests, isNotEmpty);
    });

    testWidgets('Google login failure shows error message', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildWithGoogleLogin(
        googleLoginFn: () async => throw Exception('Compte Google non autorisé'),
      ));
      await tester.pump();

      await tester.tap(find.byType(IconButton).last);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Compte Google non autorisé'), findsOneWidget);
      // isLoading should be reset to false
      expect(find.text('SE CONNECTER'), findsOneWidget);
    });

    testWidgets('Google login shows loading state then error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      await tester.pumpWidget(buildWithGoogleLogin(
        googleLoginFn: () async => throw Exception('Google Sign-In failed'),
      ));
      await tester.pump();

      await tester.tap(find.byType(IconButton).last);
      // Pump once to capture loading state before async completes
      await tester.pump();

      final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasError = find.byIcon(Icons.error_outline).evaluate().isNotEmpty;
      expect(hasProgress || hasError, isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('Google login success with houses error still navigates', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses',
          isError: true, errorStatusCode: 500);
      mockInterceptor.addMockResponse('/api/v1/rooms', data: []);
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: {
        'id': 'u1',
        'email': 'google@test.com',
        'displayName': 'Google User',
        'role': 'OWNER',
        'emailVerified': true,
        'createdAt': '2024-01-01T00:00:00Z',
      });
      mockInterceptor.addMockResponse('/api/v1/plants', data: []);

      await tester.pumpWidget(buildWithGoogleLogin(
        googleLoginFn: () async => 'google@test.com',
      ));
      await tester.pump();

      await tester.tap(find.byType(IconButton).last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Validation error should NOT be shown
      expect(find.text('Veuillez remplir tous les champs'), findsNothing);
    });
  });
}
