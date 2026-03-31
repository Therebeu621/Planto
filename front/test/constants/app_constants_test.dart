import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    group('App info', () {
      test('appName is PLANTO', () {
        expect(AppConstants.appName, 'PLANTO');
      });

      test('appVersion is 1.0.0', () {
        expect(AppConstants.appVersion, '1.0.0');
      });
    });

    group('Gemini', () {
      test('geminiApiKey is set', () {
        // Key is injected via --dart-define=GEMINI_API_KEY=... in production builds
        expect(AppConstants.geminiApiKey, isA<String>());
      });

      test('geminiModel is gemini-2.5-flash', () {
        expect(AppConstants.geminiModel, 'gemini-2.5-flash');
      });
    });

    group('API', () {
      test('apiBaseUrl returns localhost on non-Android platform', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });
        expect(AppConstants.apiBaseUrl, 'http://localhost:8080');
      });

      test('apiBaseUrl returns emulator address on Android', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });
        expect(AppConstants.apiBaseUrl, 'http://10.0.2.2:8080');
      });

      test('apiTimeout is 30 seconds', () {
        expect(AppConstants.apiTimeout, const Duration(seconds: 30));
      });
    });

    group('Animation durations', () {
      test('shortAnimation is 200ms', () {
        expect(AppConstants.shortAnimation, const Duration(milliseconds: 200));
      });

      test('mediumAnimation is 400ms', () {
        expect(AppConstants.mediumAnimation, const Duration(milliseconds: 400));
      });

      test('longAnimation is 600ms', () {
        expect(AppConstants.longAnimation, const Duration(milliseconds: 600));
      });
    });

    group('Padding values', () {
      test('paddingXS is 4.0', () {
        expect(AppConstants.paddingXS, 4.0);
      });

      test('paddingS is 8.0', () {
        expect(AppConstants.paddingS, 8.0);
      });

      test('paddingM is 16.0', () {
        expect(AppConstants.paddingM, 16.0);
      });

      test('paddingL is 24.0', () {
        expect(AppConstants.paddingL, 24.0);
      });

      test('paddingXL is 32.0', () {
        expect(AppConstants.paddingXL, 32.0);
      });
    });

    group('Border radius values', () {
      test('radiusS is 8.0', () {
        expect(AppConstants.radiusS, 8.0);
      });

      test('radiusM is 12.0', () {
        expect(AppConstants.radiusM, 12.0);
      });

      test('radiusL is 16.0', () {
        expect(AppConstants.radiusL, 16.0);
      });

      test('radiusXL is 24.0', () {
        expect(AppConstants.radiusXL, 24.0);
      });

      test('radiusRound is 30.0', () {
        expect(AppConstants.radiusRound, 30.0);
      });
    });
  });
}
