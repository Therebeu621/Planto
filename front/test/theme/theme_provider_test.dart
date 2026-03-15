import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/theme/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier', () {
    test('initial state is ThemeMode.light', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      expect(notifier.state, ThemeMode.light);
    });

    test('toggle switches from light to dark', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.toggle();

      expect(notifier.state, ThemeMode.dark);
    });

    test('toggle switches from dark back to light', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.toggle(); // light -> dark
      await notifier.toggle(); // dark -> light

      expect(notifier.state, ThemeMode.light);
    });

    test('setDark(true) sets state to dark', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.setDark(true);

      expect(notifier.state, ThemeMode.dark);
    });

    test('setDark(false) sets state to light', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.setDark(true);
      await notifier.setDark(false);

      expect(notifier.state, ThemeMode.light);
    });

    test('toggle persists dark mode to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.toggle(); // light -> dark

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dark_mode_enabled'), isTrue);
    });

    test('toggle persists light mode to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.toggle(); // light -> dark
      await notifier.toggle(); // dark -> light

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dark_mode_enabled'), isFalse);
    });

    test('setDark persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.setDark(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dark_mode_enabled'), isTrue);
    });

    test('loads dark mode from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});
      final notifier = ThemeModeNotifier();

      // _loadFromPrefs is called in constructor, give it time to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.state, ThemeMode.dark);
    });

    test('loads light mode when dark_mode_enabled is false', () async {
      SharedPreferences.setMockInitialValues({'dark_mode_enabled': false});
      final notifier = ThemeModeNotifier();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.state, ThemeMode.light);
    });

    test('loads light mode when no preference is set', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.state, ThemeMode.light);
    });
  });
}
