import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/models/plant.dart';

void main() {
  late NotificationService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = NotificationService();
  });

  group('areNotificationsEnabled', () {
    test('returns true by default', () async {
      final result = await service.areNotificationsEnabled();
      expect(result, isTrue);
    });

    test('returns false when disabled', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      final result = await service.areNotificationsEnabled();
      expect(result, isFalse);
    });

    test('returns true when explicitly enabled', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);
      final result = await service.areNotificationsEnabled();
      expect(result, isTrue);
    });
  });

  group('setNotificationsEnabled', () {
    test('sets enabled to true', () async {
      await service.setNotificationsEnabled(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications_enabled'), isTrue);
    });

    test('sets enabled to false', () async {
      await service.setNotificationsEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications_enabled'), isFalse);
    });
  });

  group('getNotificationTime', () {
    test('returns default 8:00 when not set', () async {
      final time = await service.getNotificationTime();
      expect(time.hour, 8);
      expect(time.minute, 0);
    });

    test('returns saved time', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_hour', 14);
      await prefs.setInt('reminder_minute', 30);
      final time = await service.getNotificationTime();
      expect(time.hour, 14);
      expect(time.minute, 30);
    });
  });

  group('setNotificationTime', () {
    test('saves hour and minute', () async {
      await service.setNotificationTime(10, 45);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reminder_hour'), 10);
      expect(prefs.getInt('reminder_minute'), 45);
    });

    test('overwrites previous time', () async {
      await service.setNotificationTime(8, 0);
      await service.setNotificationTime(20, 15);
      final time = await service.getNotificationTime();
      expect(time.hour, 20);
      expect(time.minute, 15);
    });
  });

  group('isHouseNotificationEnabled', () {
    test('returns true by default for any house', () async {
      final result = await service.isHouseNotificationEnabled('house1');
      expect(result, isTrue);
    });

    test('returns false for disabled house', () async {
      await service.setHouseNotificationEnabled('house1', false);
      final result = await service.isHouseNotificationEnabled('house1');
      expect(result, isFalse);
    });

    test('returns true for re-enabled house', () async {
      await service.setHouseNotificationEnabled('house1', false);
      await service.setHouseNotificationEnabled('house1', true);
      final result = await service.isHouseNotificationEnabled('house1');
      expect(result, isTrue);
    });
  });

  group('setHouseNotificationEnabled', () {
    test('disabling adds to disabled list', () async {
      await service.setHouseNotificationEnabled('h1', false);
      expect(await service.isHouseNotificationEnabled('h1'), isFalse);
    });

    test('enabling removes from disabled list', () async {
      await service.setHouseNotificationEnabled('h1', false);
      await service.setHouseNotificationEnabled('h1', true);
      expect(await service.isHouseNotificationEnabled('h1'), isTrue);
    });

    test('disabling same house twice does not duplicate', () async {
      await service.setHouseNotificationEnabled('h1', false);
      await service.setHouseNotificationEnabled('h1', false);
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notification_disabled_houses');
      expect(json, contains('h1'));
      // Count occurrences of h1
      final count = 'h1'.allMatches(json!).length;
      expect(count, 1);
    });

    test('multiple houses can be independently managed', () async {
      await service.setHouseNotificationEnabled('h1', false);
      await service.setHouseNotificationEnabled('h2', false);
      expect(await service.isHouseNotificationEnabled('h1'), isFalse);
      expect(await service.isHouseNotificationEnabled('h2'), isFalse);
      expect(await service.isHouseNotificationEnabled('h3'), isTrue);

      await service.setHouseNotificationEnabled('h1', true);
      expect(await service.isHouseNotificationEnabled('h1'), isTrue);
      expect(await service.isHouseNotificationEnabled('h2'), isFalse);
    });
  });

  group('scheduleWateringReminder', () {
    test('completes without error', () async {
      // This method just logs - verifying it doesn't throw
      final plant = _createMockPlant('p1', 'Test Plant');
      await expectLater(
        service.scheduleWateringReminder(plant),
        completes,
      );
    });

    test('completes with houseId', () async {
      final plant = _createMockPlant('p1', 'Test Plant');
      await expectLater(
        service.scheduleWateringReminder(plant, houseId: 'h1'),
        completes,
      );
    });
  });

  group('singleton', () {
    test('factory returns same instance', () {
      final a = NotificationService();
      final b = NotificationService();
      expect(identical(a, b), isTrue);
    });
  });
}

Plant _createMockPlant(String id, String nickname) {
  return Plant.fromJson({
    'id': id,
    'nickname': nickname,
    'needsWatering': true,
    'nextWateringDate': DateTime.now().toIso8601String().split('T')[0],
  });
}
