import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/utils/extensions.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StringExtensions', () {
    group('capitalize', () {
      test('returns empty string for empty string', () {
        expect(''.capitalize, '');
      });

      test('capitalizes single character', () {
        expect('a'.capitalize, 'A');
      });

      test('capitalizes first letter of a word', () {
        expect('hello'.capitalize, 'Hello');
      });

      test('keeps already capitalized string unchanged', () {
        expect('Hello'.capitalize, 'Hello');
      });

      test('capitalizes first letter, keeps rest as-is', () {
        expect('hELLO'.capitalize, 'HELLO');
      });

      test('works with numbers as first character', () {
        expect('1abc'.capitalize, '1abc');
      });
    });

    group('isValidEmail', () {
      test('valid email returns true', () {
        expect('test@example.com'.isValidEmail, isTrue);
      });

      test('valid email with subdomain returns true', () {
        expect('user@mail.example.com'.isValidEmail, isTrue);
      });

      test('valid email with dots in local part returns true', () {
        expect('first.last@example.com'.isValidEmail, isTrue);
      });

      test('valid email with hyphen in local part returns true', () {
        expect('user-name@example.com'.isValidEmail, isTrue);
      });

      test('valid email with underscore returns true', () {
        expect('user_name@example.com'.isValidEmail, isTrue);
      });

      test('empty string returns false', () {
        expect(''.isValidEmail, isFalse);
      });

      test('string without @ returns false', () {
        expect('testexample.com'.isValidEmail, isFalse);
      });

      test('string without domain returns false', () {
        expect('test@'.isValidEmail, isFalse);
      });

      test('string without TLD returns false', () {
        expect('test@example'.isValidEmail, isFalse);
      });

      test('string with spaces returns false', () {
        expect('test @example.com'.isValidEmail, isFalse);
      });

      test('string with double @ returns false', () {
        expect('test@@example.com'.isValidEmail, isFalse);
      });

      test('valid email with 2-char TLD returns true', () {
        expect('user@example.fr'.isValidEmail, isTrue);
      });

      test('valid email with 4-char TLD returns true', () {
        expect('user@example.info'.isValidEmail, isTrue);
      });
    });
  });

  group('ContextExtensions', () {
    testWidgets('theme returns current ThemeData', (tester) async {
      late ThemeData capturedTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              capturedTheme = context.theme;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedTheme, isNotNull);
      expect(capturedTheme.brightness, Brightness.light);
    });

    testWidgets('colorScheme returns current ColorScheme', (tester) async {
      late ColorScheme capturedColorScheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              capturedColorScheme = context.colorScheme;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedColorScheme, isNotNull);
    });

    testWidgets('textTheme returns current TextTheme', (tester) async {
      late TextTheme capturedTextTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              capturedTextTheme = context.textTheme;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedTextTheme, isNotNull);
    });

    testWidgets('screenSize returns a valid Size', (tester) async {
      late Size capturedSize;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedSize = context.screenSize;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedSize.width, greaterThan(0));
      expect(capturedSize.height, greaterThan(0));
    });

    testWidgets('screenWidth returns positive value', (tester) async {
      late double capturedWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedWidth = context.screenWidth;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedWidth, greaterThan(0));
    });

    testWidgets('screenHeight returns positive value', (tester) async {
      late double capturedHeight;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedHeight = context.screenHeight;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedHeight, greaterThan(0));
    });

    testWidgets('isDarkMode returns false for light theme', (tester) async {
      late bool capturedIsDark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              capturedIsDark = context.isDarkMode;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedIsDark, isFalse);
    });

    testWidgets('isDarkMode returns true for dark theme', (tester) async {
      late bool capturedIsDark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              capturedIsDark = context.isDarkMode;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(capturedIsDark, isTrue);
    });

    testWidgets('showSnackBar displays a snackbar with message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => context.showSnackBar('Test message'),
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('showSnackBar with isError=true uses error color',
        (tester) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                scheme = context.colorScheme;
                return ElevatedButton(
                  onPressed: () =>
                      context.showSnackBar('Error msg', isError: true),
                  child: const Text('ShowError'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('ShowError'));
      await tester.pumpAndSettle();

      expect(find.text('Error msg'), findsOneWidget);
      // Verify snackbar is displayed with error background
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, scheme.error);
    });

    testWidgets('showSnackBar with isError=false uses primary color',
        (tester) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                scheme = context.colorScheme;
                return ElevatedButton(
                  onPressed: () => context.showSnackBar('Info msg'),
                  child: const Text('ShowInfo'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('ShowInfo'));
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, scheme.primary);
    });

    testWidgets('showSnackBar has floating behavior', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => context.showSnackBar('Floating'),
                  child: const Text('ShowFloat'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('ShowFloat'));
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
    });
  });
}
