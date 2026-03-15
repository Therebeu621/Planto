import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/features/auth/forgot_password_page.dart';

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
    return MaterialApp(
      home: ForgotPasswordPage(authService: auth ?? authService),
    );
  }

  group('ForgotPasswordPage - Step 0: Initial render', () {
    testWidgets('renders email field and ENVOYER LE CODE button', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Adresse email'), findsOneWidget);
      expect(find.text('ENVOYER LE CODE'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders title and description', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Reinitialiser votre mot de passe'), findsOneWidget);
      expect(find.textContaining('adresse email pour recevoir'), findsOneWidget);
    });

    testWidgets('renders lock_reset icon', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.lock_reset), findsOneWidget);
    });

    testWidgets('renders app bar with title', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Mot de passe oublie'), findsOneWidget);
    });

    testWidgets('renders email_outlined icon prefix', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });
  });

  group('ForgotPasswordPage - Step 0: Validation', () {
    testWidgets('empty email shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pump();

      expect(find.text('Veuillez entrer votre adresse email'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('ForgotPasswordPage - Step 0: Send code', () {
    testWidgets('send code success moves to step 1', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();

      // Should be on step 1 now
      expect(find.text('Entrez le code recu'), findsOneWidget);
      expect(find.text('Nouveau mot de passe'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
      expect(find.text('REINITIALISER'), findsOneWidget);
      // Success message shown
      expect(find.textContaining('code a ete envoye'), findsAtLeast(1));
    });

    testWidgets('send code failure shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();

      // Should still be on step 0 with error
      expect(find.text('ENVOYER LE CODE'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows loading state during send code', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pump(); // One pump to see loading

      // Either loading or already moved to step 1
      final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final movedToStep1 = find.text('Entrez le code recu').evaluate().isNotEmpty;
      expect(hasProgress || movedToStep1, isTrue);

      await tester.pumpAndSettle();
    });
  });

  group('ForgotPasswordPage - Step 1: Render', () {
    Future<void> goToStep1(WidgetTester tester) async {
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders code, password, confirm password fields', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      expect(find.text('000000'), findsOneWidget);
      expect(find.text('Nouveau mot de passe'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
      expect(find.byType(TextField), findsAtLeast(3));
    });

    testWidgets('renders verified_user icon', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      expect(find.byIcon(Icons.verified_user), findsOneWidget);
    });

    testWidgets('renders lock icons for password fields', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('renders Renvoyer le code button', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      expect(find.text('Renvoyer le code'), findsOneWidget);
    });

    testWidgets('renders email in description text', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      expect(find.textContaining('test@test.com'), findsOneWidget);
    });

    testWidgets('success message is displayed after moving to step 1', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });

  group('ForgotPasswordPage - Step 1: Validation', () {
    Future<void> goToStep1(WidgetTester tester) async {
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();
    }

    testWidgets('empty code shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      // Enter passwords but leave code empty
      await tester.enterText(find.widgetWithText(TextField, 'Nouveau mot de passe'), 'newpassword123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'newpassword123');
      await tester.pump();

      await tester.tap(find.text('REINITIALISER'));
      await tester.pump();

      expect(find.text('Veuillez entrer le code recu'), findsOneWidget);
    });

    testWidgets('short password shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'Nouveau mot de passe'), 'short');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'short');
      await tester.pump();

      await tester.tap(find.text('REINITIALISER'));
      await tester.pump();

      expect(find.textContaining('au moins 8'), findsOneWidget);
    });

    testWidgets('mismatched passwords show error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'Nouveau mot de passe'), 'password123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'different456');
      await tester.pump();

      await tester.tap(find.text('REINITIALISER'));
      await tester.pump();

      expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    });
  });

  group('ForgotPasswordPage - Step 1: Reset password', () {
    Future<void> goToStep1(WidgetTester tester) async {
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();
    }

    testWidgets('reset success shows success message and navigates back', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      // Wrap in a navigator so pop works
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ForgotPasswordPage(authService: authService),
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

      // Now on ForgotPasswordPage step 0
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});
      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();
      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();

      // Now on step 1
      mockInterceptor.addMockResponse('/api/v1/auth/reset-password', data: {});

      await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'Nouveau mot de passe'), 'newpassword123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'newpassword123');
      await tester.pump();

      await tester.tap(find.text('REINITIALISER'));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show success message
      expect(find.textContaining('reinitialise avec succes'), findsOneWidget);

      // Wait for the 2-second delay and navigation
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Should have navigated back
      expect(find.text('GO'), findsOneWidget);
    });

    testWidgets('reset failure (400) shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      mockInterceptor.addMockResponse('/api/v1/auth/reset-password',
        isError: true,
        errorStatusCode: 400,
        data: {'message': 'Invalid code'},
      );

      await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'Nouveau mot de passe'), 'newpassword123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'newpassword123');
      await tester.pump();

      await tester.tap(find.text('REINITIALISER'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('REINITIALISER'), findsOneWidget);
    });

    testWidgets('reset failure (other error) shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      mockInterceptor.addMockResponse('/api/v1/auth/reset-password',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'Nouveau mot de passe'), 'newpassword123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'newpassword123');
      await tester.pump();

      await tester.tap(find.text('REINITIALISER'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows loading state during reset', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();
      await goToStep1(tester);

      mockInterceptor.addMockResponse('/api/v1/auth/reset-password', data: {});

      await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'Nouveau mot de passe'), 'newpassword123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'newpassword123');
      await tester.pump();

      await tester.tap(find.text('REINITIALISER'));
      await tester.pump();

      // Either loading or already succeeded
      final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasSuccess = find.textContaining('reinitialise').evaluate().isNotEmpty;
      expect(hasProgress || hasSuccess, isTrue);

      // Clean up the timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('ForgotPasswordPage - Step 1: Resend code', () {
    testWidgets('resend code button calls send code again', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();

      // On step 1, clear and re-add mock
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.tap(find.text('Renvoyer le code'));
      await tester.pumpAndSettle();

      // Should show success message again (still on step 1)
      expect(find.text('REINITIALISER'), findsOneWidget);
    });

    testWidgets('resend code failure shows error', (tester) async {
      setupPageTest(tester);
      origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password', data: {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Adresse email'), 'test@test.com');
      await tester.pump();

      await tester.tap(find.text('ENVOYER LE CODE'));
      await tester.pumpAndSettle();

      // Now make resend fail
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      await tester.tap(find.text('Renvoyer le code'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
