import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme static colors', () {
    test('primaryColor is correct', () {
      expect(AppTheme.primaryColor, const Color(0xFF4A6741));
    });

    test('secondaryColor is correct', () {
      expect(AppTheme.secondaryColor, const Color(0xFF6B8E63));
    });

    test('accentColor is correct', () {
      expect(AppTheme.accentColor, const Color(0xFF8FBC8F));
    });

    test('backgroundColor is correct', () {
      expect(AppTheme.backgroundColor, const Color(0xFFCCD5C8));
    });

    test('surfaceColor is correct', () {
      expect(AppTheme.surfaceColor, const Color(0xFFFFFFFF));
    });

    test('errorColor is correct', () {
      expect(AppTheme.errorColor, const Color(0xFFE74C3C));
    });

    test('successColor is correct', () {
      expect(AppTheme.successColor, const Color(0xFF27AE60));
    });

    test('textPrimary is correct', () {
      expect(AppTheme.textPrimary, const Color(0xFF2C3E2D));
    });

    test('textSecondary is correct', () {
      expect(AppTheme.textSecondary, const Color(0xFF6B7B6C));
    });

    test('darkBackgroundColor is correct', () {
      expect(AppTheme.darkBackgroundColor, const Color(0xFF1A2F1A));
    });

    test('darkSurfaceColor is correct', () {
      expect(AppTheme.darkSurfaceColor, const Color(0xFF2D4A2D));
    });

    test('darkCardColor is correct', () {
      expect(AppTheme.darkCardColor, const Color(0xFF253D25));
    });

    test('darkInputFill is correct', () {
      expect(AppTheme.darkInputFill, const Color(0xFF3A5A3A));
    });

    test('darkTextPrimary is correct', () {
      expect(AppTheme.darkTextPrimary, const Color(0xFFE8EDE8));
    });

    test('darkTextSecondary is correct', () {
      expect(AppTheme.darkTextSecondary, const Color(0xFFA8B8A8));
    });

    test('darkDivider is correct', () {
      expect(AppTheme.darkDivider, const Color(0xFF3E5E3E));
    });

    test('darkBorder is correct', () {
      expect(AppTheme.darkBorder, const Color(0xFF4A6A4A));
    });
  });

  group('AppTheme lightTheme', () {
    testWidgets('lightTheme is not null and has correct properties',
        (tester) async {
      final light = AppTheme.lightTheme;
      expect(light, isNotNull);
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, AppTheme.backgroundColor);
      expect(light.colorScheme.primary, AppTheme.primaryColor);
      expect(light.colorScheme.secondary, AppTheme.secondaryColor);
      expect(light.colorScheme.error, AppTheme.errorColor);
      expect(light.useMaterial3, isTrue);
    });
  });

  group('AppTheme darkTheme', () {
    testWidgets('darkTheme is not null and has correct properties',
        (tester) async {
      final dark = AppTheme.darkTheme;
      expect(dark, isNotNull);
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AppTheme.darkBackgroundColor);
      expect(dark.colorScheme.primary, AppTheme.accentColor);
      expect(dark.colorScheme.secondary, AppTheme.secondaryColor);
      expect(dark.colorScheme.error, AppTheme.errorColor);
      expect(dark.useMaterial3, isTrue);
      expect(dark.dividerColor, AppTheme.darkDivider);
    });
  });

  group('AppTheme context-aware helpers - light theme', () {
    Widget buildLightApp(void Function(BuildContext) callback) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            callback(context);
            return const SizedBox();
          },
        ),
      );
    }

    testWidgets('isDark returns false in light theme', (tester) async {
      late bool result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.isDark(ctx);
      }));
      expect(result, isFalse);
    });

    testWidgets('scaffoldBg returns backgroundColor in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.scaffoldBg(ctx);
      }));
      expect(result, AppTheme.backgroundColor);
    });

    testWidgets('cardBg returns surfaceColor in light theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.cardBg(ctx);
      }));
      expect(result, AppTheme.surfaceColor);
    });

    testWidgets('inputFill returns light grey in light theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.inputFill(ctx);
      }));
      expect(result, const Color(0xFFF8F9FA));
    });

    testWidgets('lightBg returns 0xFFF5F5F5 in light theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.lightBg(ctx);
      }));
      expect(result, const Color(0xFFF5F5F5));
    });

    testWidgets('textPrimaryC returns textPrimary in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.textPrimaryC(ctx);
      }));
      expect(result, AppTheme.textPrimary);
    });

    testWidgets('textSecondaryC returns textSecondary in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.textSecondaryC(ctx);
      }));
      expect(result, AppTheme.textSecondary);
    });

    testWidgets('textGrey returns grey.shade600 in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.textGrey(ctx);
      }));
      expect(result, Colors.grey.shade600);
    });

    testWidgets('textGreyDark returns grey.shade700 in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.textGreyDark(ctx);
      }));
      expect(result, Colors.grey.shade700);
    });

    testWidgets('divider returns grey.shade300 in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.divider(ctx);
      }));
      expect(result, Colors.grey.shade300);
    });

    testWidgets('border returns grey.shade300 in light theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.border(ctx);
      }));
      expect(result, Colors.grey.shade300);
    });

    testWidgets('borderLight returns grey.shade200 in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.borderLight(ctx);
      }));
      expect(result, Colors.grey.shade200);
    });

    testWidgets('shadow returns black with 0.1 opacity in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.shadow(ctx);
      }));
      expect(result, Colors.black.withOpacity(0.1));
    });

    testWidgets('shadowSoft returns black with 0.05 opacity in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.shadowSoft(ctx);
      }));
      expect(result, Colors.black.withOpacity(0.05));
    });

    testWidgets('onPrimary returns white', (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.onPrimary(ctx);
      }));
      expect(result, Colors.white);
    });

    testWidgets('chipBg returns 0xFFF0F4EF in light theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.chipBg(ctx);
      }));
      expect(result, const Color(0xFFF0F4EF));
    });

    testWidgets('errorBgLight returns red.shade50 in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.errorBgLight(ctx);
      }));
      expect(result, Colors.red.shade50);
    });

    testWidgets('errorBorder returns red.shade200 in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.errorBorder(ctx);
      }));
      expect(result, Colors.red.shade200);
    });

    testWidgets('errorText returns red.shade700 in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.errorText(ctx);
      }));
      expect(result, Colors.red.shade700);
    });

    testWidgets('overlayWhite returns white with given opacity in light theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildLightApp((ctx) {
        result = AppTheme.overlayWhite(ctx, 0.5);
      }));
      expect(result, Colors.white.withOpacity(0.5));
    });
  });

  group('AppTheme context-aware helpers - dark theme', () {
    Widget buildDarkApp(void Function(BuildContext) callback) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) {
            callback(context);
            return const SizedBox();
          },
        ),
      );
    }

    testWidgets('isDark returns true in dark theme', (tester) async {
      late bool result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.isDark(ctx);
      }));
      expect(result, isTrue);
    });

    testWidgets('scaffoldBg returns darkBackgroundColor in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.scaffoldBg(ctx);
      }));
      expect(result, AppTheme.darkBackgroundColor);
    });

    testWidgets('cardBg returns darkCardColor in dark theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.cardBg(ctx);
      }));
      expect(result, AppTheme.darkCardColor);
    });

    testWidgets('inputFill returns darkInputFill in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.inputFill(ctx);
      }));
      expect(result, AppTheme.darkInputFill);
    });

    testWidgets('lightBg returns darkSurfaceColor in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.lightBg(ctx);
      }));
      expect(result, AppTheme.darkSurfaceColor);
    });

    testWidgets('textPrimaryC returns darkTextPrimary in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.textPrimaryC(ctx);
      }));
      expect(result, AppTheme.darkTextPrimary);
    });

    testWidgets('textSecondaryC returns darkTextSecondary in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.textSecondaryC(ctx);
      }));
      expect(result, AppTheme.darkTextSecondary);
    });

    testWidgets('textGrey returns grey.shade400 in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.textGrey(ctx);
      }));
      expect(result, Colors.grey.shade400);
    });

    testWidgets('textGreyDark returns grey.shade300 in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.textGreyDark(ctx);
      }));
      expect(result, Colors.grey.shade300);
    });

    testWidgets('divider returns darkDivider in dark theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.divider(ctx);
      }));
      expect(result, AppTheme.darkDivider);
    });

    testWidgets('border returns darkBorder in dark theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.border(ctx);
      }));
      expect(result, AppTheme.darkBorder);
    });

    testWidgets('borderLight returns darkDivider in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.borderLight(ctx);
      }));
      expect(result, AppTheme.darkDivider);
    });

    testWidgets('shadow returns black with 0.3 opacity in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.shadow(ctx);
      }));
      expect(result, Colors.black.withOpacity(0.3));
    });

    testWidgets('shadowSoft returns black with 0.2 opacity in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.shadowSoft(ctx);
      }));
      expect(result, Colors.black.withOpacity(0.2));
    });

    testWidgets('onPrimary returns white in dark theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.onPrimary(ctx);
      }));
      expect(result, Colors.white);
    });

    testWidgets('chipBg returns darkInputFill in dark theme', (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.chipBg(ctx);
      }));
      expect(result, AppTheme.darkInputFill);
    });

    testWidgets('errorBgLight returns red.shade900 with opacity in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.errorBgLight(ctx);
      }));
      expect(result, Colors.red.shade900.withOpacity(0.3));
    });

    testWidgets('errorBorder returns red.shade700 in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.errorBorder(ctx);
      }));
      expect(result, Colors.red.shade700);
    });

    testWidgets('errorText returns red.shade300 in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.errorText(ctx);
      }));
      expect(result, Colors.red.shade300);
    });

    testWidgets(
        'overlayWhite returns white with halved opacity in dark theme',
        (tester) async {
      late Color result;
      await tester.pumpWidget(buildDarkApp((ctx) {
        result = AppTheme.overlayWhite(ctx, 0.8);
      }));
      expect(result, Colors.white.withOpacity(0.4));
    });
  });
}
