import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:planto/core/services/api_client.dart';

/// Top-level background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

/// Service for managing Firebase Cloud Messaging (push notifications).
/// Handles token registration, foreground/background messages.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _currentToken;
  bool _isInitialized = false;

  /// Initialize FCM: request permissions, get token, listen for messages
  Future<void> init() async {
    if (_isInitialized) return;

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // Get FCM token
    _currentToken = await _messaging.getToken();
    debugPrint('FCM token: $_currentToken');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
      _currentToken = newToken;
      _registerTokenWithBackend(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle message tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    _isInitialized = true;
    debugPrint('FcmService initialized');
  }

  /// Register the current FCM token with the backend
  Future<void> registerToken() async {
    if (_currentToken == null) {
      _currentToken = await _messaging.getToken();
    }
    if (_currentToken != null) {
      await _registerTokenWithBackend(_currentToken!);
    }
  }

  /// Unregister the FCM token from the backend (on logout)
  Future<void> unregisterToken() async {
    if (_currentToken == null) return;
    try {
      await ApiClient.instance.dio.delete(
        '/api/v1/auth/device-token',
        data: {'fcmToken': _currentToken},
      );
      debugPrint('FCM token unregistered from backend');
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
    }
  }

  /// Send the FCM token to the backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiClient.instance.dio.post(
        '/api/v1/auth/device-token',
        data: {
          'fcmToken': token,
          'deviceInfo': defaultTargetPlatform.name,
        },
      );
      debugPrint('FCM token registered with backend');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Handle foreground messages: show a local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show as local notification
    const androidDetails = AndroidNotificationDetails(
      'push_notifications',
      'Notifications',
      channelDescription: 'Notifications push de Planto',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    FlutterLocalNotificationsPlugin().show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }

  /// Handle message tap (navigate to relevant screen)
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('FCM message tapped: ${message.data}');
    // TODO: Navigate to plant detail or home based on message.data
  }
}
