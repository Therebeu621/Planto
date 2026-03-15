import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/widgets/app_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AppButton', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Click Me', onPressed: () {}),
      ));

      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('default variant renders ElevatedButton', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Test', onPressed: () {}),
      ));

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('outlined variant renders OutlinedButton', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Test', onPressed: () {}, isOutlined: true),
      ));

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('tapping calls onPressed', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Tap', onPressed: () => pressed = true),
      ));

      await tester.tap(find.text('Tap'));
      expect(pressed, isTrue);
    });

    testWidgets('tapping outlined calls onPressed', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(buildApp(
        AppButton(
          text: 'Tap',
          onPressed: () => pressed = true,
          isOutlined: true,
        ),
      ));

      await tester.tap(find.text('Tap'));
      expect(pressed, isTrue);
    });

    testWidgets('loading shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Loading', onPressed: () {}, isLoading: true),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('loading outlined shows CircularProgressIndicator',
        (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(
          text: 'Loading',
          onPressed: () {},
          isLoading: true,
          isOutlined: true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('loading disables tap', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(buildApp(
        AppButton(
          text: 'Tap',
          onPressed: () => pressed = true,
          isLoading: true,
        ),
      ));

      await tester.tap(find.byType(ElevatedButton));
      expect(pressed, isFalse);
    });

    testWidgets('loading disables tap on outlined variant', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(buildApp(
        AppButton(
          text: 'Tap',
          onPressed: () => pressed = true,
          isLoading: true,
          isOutlined: true,
        ),
      ));

      await tester.tap(find.byType(OutlinedButton));
      expect(pressed, isFalse);
    });

    testWidgets('custom width is applied', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Wide', onPressed: () {}, width: 300),
      ));

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 300);
    });

    testWidgets('custom height is applied', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Tall', onPressed: () {}, height: 60),
      ));

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, 60);
    });

    testWidgets('default height is 48', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'Default', onPressed: () {}),
      ));

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, 48);
    });

    testWidgets('null onPressed disables the button', (tester) async {
      await tester.pumpWidget(buildApp(
        const AppButton(text: 'Disabled', onPressed: null),
      ));

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('width defaults to null (no constraint)', (tester) async {
      await tester.pumpWidget(buildApp(
        AppButton(text: 'NoWidth', onPressed: () {}),
      ));

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, isNull);
    });
  });
}
