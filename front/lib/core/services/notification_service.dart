import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:planto/core/models/plant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for managing local notifications (watering reminders)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Use same keys as profile_page.dart
  static const String _notificationHourKey = 'reminder_hour';
  static const String _notificationMinuteKey = 'reminder_minute';
  static const String _notificationsEnabledKey = 'notifications_enabled';

  // Per-house notification preferences
  // Stores house IDs with notifications DISABLED (default = enabled)
  static const String _disabledHousesKey = 'notification_disabled_houses';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to plant detail page using payload (plantId)
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return false;
  }

  /// Check if notifications are enabled in settings
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  /// Enable or disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);

    if (!enabled) {
      await cancelAllReminders();
    }
  }

  /// Get the configured notification time (default: 8:00)
  Future<({int hour, int minute})> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_notificationHourKey) ?? 8;
    final minute = prefs.getInt(_notificationMinuteKey) ?? 0;
    return (hour: hour, minute: minute);
  }

  /// Set the notification time
  Future<void> setNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notificationHourKey, hour);
    await prefs.setInt(_notificationMinuteKey, minute);
  }

  // ============ Per-House Notification Preferences ============

  /// Get list of house IDs with notifications disabled
  Future<List<String>> _getDisabledHouses() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_disabledHousesKey);
    if (json == null) return [];
    return List<String>.from(jsonDecode(json));
  }

  /// Save list of house IDs with notifications disabled
  Future<void> _saveDisabledHouses(List<String> houseIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_disabledHousesKey, jsonEncode(houseIds));
  }

  /// Check if notifications are enabled for a specific house
  /// Default: enabled (true)
  Future<bool> isHouseNotificationEnabled(String houseId) async {
    final disabledHouses = await _getDisabledHouses();
    return !disabledHouses.contains(houseId);
  }

  /// Enable or disable notifications for a specific house
  Future<void> setHouseNotificationEnabled(String houseId, bool enabled) async {
    final disabledHouses = await _getDisabledHouses();

    if (enabled) {
      // Remove from disabled list (enable notifications)
      disabledHouses.remove(houseId);
    } else {
      // Add to disabled list (disable notifications)
      if (!disabledHouses.contains(houseId)) {
        disabledHouses.add(houseId);
      }
    }

    await _saveDisabledHouses(disabledHouses);
    debugPrint('House $houseId notifications: ${enabled ? 'enabled' : 'disabled'}');
  }

  // ============ Scheduling Methods ============

  /// Schedule a watering reminder for a plant (called after watering)
  /// Note: With summary notifications, this triggers a log but the actual
  /// reschedule happens via scheduleAllReminders on app load
  /// [houseId] is optional - if provided, checks if house notifications are enabled
  Future<void> scheduleWateringReminder(Plant plant, {String? houseId}) async {
    // With summary notifications, individual scheduling is handled by scheduleAllReminders
    // This method is kept for API compatibility but just logs the action
    debugPrint('Plant ${plant.nickname} watered - notifications will update on next app load');
  }

  /// Cancel watering reminder for a specific plant
  Future<void> cancelReminder(String plantId) async {
    if (!_isInitialized) return;
    final notificationId = plantId.hashCode.abs() % 2147483647;
    await _notifications.cancel(notificationId);
    debugPrint('Cancelled notification for plant $plantId');
  }

  /// Cancel all watering reminders
  Future<void> cancelAllReminders() async {
    if (!_isInitialized) return;
    await _notifications.cancelAll();
    debugPrint('Cancelled all notifications');
  }

  /// Schedule summary reminders grouped by date
  /// Instead of one notification per plant, schedules one per day with count
  /// [houseId] is optional - if provided, only schedules for that house
  Future<void> scheduleAllReminders(List<Plant> plants, {String? houseId}) async {
    if (!_isInitialized) await init();

    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    // Check per-house notifications setting
    if (houseId != null) {
      final houseEnabled = await isHouseNotificationEnabled(houseId);
      if (!houseEnabled) {
        debugPrint('Skipping all notifications - house notifications disabled');
        return;
      }
    }

    // Cancel all existing reminders first
    await cancelAllReminders();

    // Group plants by watering date
    final Map<DateTime, List<Plant>> plantsByDate = {};
    for (final plant in plants) {
      if (plant.nextWateringDate != null) {
        final date = DateTime(
          plant.nextWateringDate!.year,
          plant.nextWateringDate!.month,
          plant.nextWateringDate!.day,
        );
        plantsByDate.putIfAbsent(date, () => []).add(plant);
      }
    }

    // Schedule one summary notification per date
    final notificationTime = await getNotificationTime();
    final now = DateTime.now();

    for (final entry in plantsByDate.entries) {
      final date = entry.key;
      final plantsForDate = entry.value;
      final count = plantsForDate.length;

      // Create scheduled date with configured time
      final scheduledDate = DateTime(
        date.year,
        date.month,
        date.day,
        notificationTime.hour,
        notificationTime.minute,
      );

      // Don't schedule if the date is in the past
      if (scheduledDate.isBefore(now)) {
        debugPrint('Skipping summary for $date - date is in the past');
        continue;
      }

      // Schedule summary notification
      await _scheduleDailySummary(scheduledDate, count, plantsForDate);
    }

    debugPrint('Scheduled summary notifications for ${plantsByDate.length} days');
  }

  /// Schedule a daily summary notification
  Future<void> _scheduleDailySummary(DateTime scheduledDate, int plantCount, List<Plant> plants) async {
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Use date as unique ID (one notification per day)
    final notificationId = scheduledDate.millisecondsSinceEpoch ~/ 86400000; // Days since epoch

    // Build notification content
    final title = 'Planto';
    final body = plantCount == 1
        ? '1 plante a arroser aujourd\'hui'
        : '$plantCount plantes a arroser aujourd\'hui';

    // Android notification details
    const androidDetails = AndroidNotificationDetails(
      'watering_reminders',
      'Rappels d\'arrosage',
      channelDescription: 'Notifications pour rappeler d\'arroser vos plantes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(''),
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      tzScheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'summary_${scheduledDate.toIso8601String()}',
    );

    debugPrint('Scheduled summary notification: $body at $scheduledDate');
  }

  /// Reschedule all reminders (useful after changing notification time)
  Future<void> rescheduleAllReminders(List<Plant> plants, {String? houseId}) async {
    await scheduleAllReminders(plants, houseId: houseId);
  }

  /// Cancel all reminders for plants in a specific house
  /// Note: This cancels ALL scheduled notifications. For per-house cancellation,
  /// you would need to track which notifications belong to which house.
  Future<void> cancelHouseReminders(List<Plant> plants) async {
    for (final plant in plants) {
      await cancelReminder(plant.id);
    }
    debugPrint('Cancelled ${plants.length} house plant reminders');
  }

  /// Show an immediate test notification
  Future<void> showTestNotification() async {
    if (!_isInitialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'watering_reminders',
      'Rappels d\'arrosage',
      channelDescription: 'Notifications pour rappeler d\'arroser vos plantes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Test de notification',
      'Les notifications fonctionnent correctement !',
      notificationDetails,
    );
  }
}
