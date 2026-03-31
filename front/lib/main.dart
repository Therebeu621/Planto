import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planto/core/services/fcm_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/core/theme/theme_provider.dart';
import 'package:planto/features/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  // Initialize Firebase (skip on web if not configured)
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize notification services (not supported on web)
    await NotificationService().init();
    try {
      await FcmService().init();
    } catch (e) {
      debugPrint('FCM init failed (non-blocking): $e');
    }
  } else {
    debugPrint('Running on web — Firebase & push notifications disabled');
  }

  runApp(
    DevicePreview(
      enabled: kDebugMode,
      builder: (context) => const ProviderScope(
        child: PlantoApp(),
      ),
    ),
  );
}

class PlantoApp extends ConsumerWidget {
  const PlantoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PLANTO',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const LoginPage(),
    );
  }
}
