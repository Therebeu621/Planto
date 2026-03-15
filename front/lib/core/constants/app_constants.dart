import 'package:flutter/foundation.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  /// App name
  static const String appName = 'PLANTO';

  /// App version
  static const String appVersion = '1.0.0';



  /// Cle API Google Gemini — injectée via --dart-define=GEMINI_API_KEY=...
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Modele Gemini a utiliser
  static const String geminiModel = 'gemini-flash-latest';

  /// API base URL (Quarkus backend)
  /// - localhost for web/desktop/iOS simulator
  /// - 10.0.2.2 for Android emulator
  /// - Your Mac's IP for physical device
  ///
  static const String physicalDeviceIp = '10.236.15.213'; // IP actuelle du Mac

  static String get apiBaseUrl {
    // For Android emulator, use 10.0.2.2
    // For iOS simulator or web, use localhost
    // For physical device, use your Mac's IP
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 = localhost pour l'émulateur Android
      // Pour appareil physique, utilisez _physicalDeviceIp
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Timeout duration for API calls
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  /// Padding values
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  /// Border radius values
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusRound = 30.0;
}
