import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/care_log.dart';

void main() {
  // ==================== CareLog.fromJson ====================

  group('CareLog.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': 'cl1',
        'action': 'WATERING',
        'notes': 'Gave extra water',
        'performedAt': '2026-03-10T08:30:00Z',
        'performedByName': 'Alice',
      };
      final log = CareLog.fromJson(json);
      expect(log.id, 'cl1');
      expect(log.action, 'WATERING');
      expect(log.notes, 'Gave extra water');
      expect(log.performedAt, isNotNull);
      expect(log.performedByName, 'Alice');
    });

    test('handles null notes', () {
      final json = {
        'id': 'cl2',
        'action': 'FERTILIZING',
        'performedAt': '2026-03-10T08:30:00Z',
      };
      final log = CareLog.fromJson(json);
      expect(log.notes, isNull);
    });

    test('handles null performedByName', () {
      final json = {
        'id': 'cl3',
        'action': 'PRUNING',
        'performedAt': '2026-03-10T08:30:00Z',
      };
      final log = CareLog.fromJson(json);
      expect(log.performedByName, isNull);
    });

    test('parses ISO date correctly', () {
      final json = {
        'id': 'cl4',
        'action': 'WATERING',
        'performedAt': '2025-12-25T14:00:00Z',
      };
      final log = CareLog.fromJson(json);
      expect(log.performedAt.year, 2025);
      expect(log.performedAt.month, 12);
      expect(log.performedAt.day, 25);
    });

    test('throws on invalid date format', () {
      final json = {
        'id': 'cl5',
        'action': 'WATERING',
        'performedAt': 'not-a-date',
      };
      expect(() => CareLog.fromJson(json), throwsFormatException);
    });

    test('throws on missing performedAt', () {
      final json = {
        'id': 'cl6',
        'action': 'WATERING',
      };
      expect(() => CareLog.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  // ==================== CareLog.actionDisplay ====================

  group('CareLog.actionDisplay', () {
    CareLog makeLog(String action) => CareLog(
          id: '1',
          action: action,
          performedAt: DateTime.now(),
        );

    test('WATERING -> Arrosage', () {
      expect(makeLog('WATERING').actionDisplay, 'Arrosage');
    });

    test('FERTILIZING -> Fertilisation', () {
      expect(makeLog('FERTILIZING').actionDisplay, 'Fertilisation');
    });

    test('REPOTTING -> Rempotage', () {
      expect(makeLog('REPOTTING').actionDisplay, 'Rempotage');
    });

    test('PRUNING -> Taille', () {
      expect(makeLog('PRUNING').actionDisplay, 'Taille');
    });

    test('TREATMENT -> Traitement', () {
      expect(makeLog('TREATMENT').actionDisplay, 'Traitement');
    });

    test('NOTE -> Memo', () {
      expect(makeLog('NOTE').actionDisplay, 'Memo');
    });

    test('unknown action returns itself', () {
      expect(makeLog('CUSTOM_ACTION').actionDisplay, 'CUSTOM_ACTION');
    });
  });

  // ==================== CareLog.actionIcon ====================

  group('CareLog.actionIcon', () {
    CareLog makeLog(String action) => CareLog(
          id: '1',
          action: action,
          performedAt: DateTime.now(),
        );

    test('returns correct emoji for each known action', () {
      expect(makeLog('WATERING').actionIcon, '💧');
      expect(makeLog('FERTILIZING').actionIcon, '🌱');
      expect(makeLog('REPOTTING').actionIcon, '🪴');
      expect(makeLog('PRUNING').actionIcon, '✂️');
      expect(makeLog('TREATMENT').actionIcon, '💊');
      expect(makeLog('NOTE').actionIcon, '📝');
    });

    test('returns default emoji for unknown action', () {
      expect(makeLog('UNKNOWN').actionIcon, '🌿');
    });
  });

  // ==================== CareLog.timeAgo ====================

  group('CareLog.timeAgo', () {
    test('returns minutes for very recent actions', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      expect(log.timeAgo, contains('min'));
    });

    test('returns hours for same-day actions', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(log.timeAgo, contains('h'));
    });

    test('returns Hier for yesterday', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(log.timeAgo, 'Hier');
    });

    test('returns jours for 2-6 days ago', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      expect(log.timeAgo, contains('jours'));
    });

    test('returns sem. for 1-4 weeks ago', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(days: 14)),
      );
      expect(log.timeAgo, contains('sem.'));
    });

    test('returns mois for 30+ days ago', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(days: 60)),
      );
      expect(log.timeAgo, contains('mois'));
    });

    test('returns 0 min for just now', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now(),
      );
      expect(log.timeAgo, contains('min'));
    });

    test('handles exactly 7 days (1 week)', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(days: 7)),
      );
      expect(log.timeAgo, contains('sem.'));
    });

    test('handles exactly 30 days (1 month)', () {
      final log = CareLog(
        id: '1',
        action: 'WATERING',
        performedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(log.timeAgo, contains('mois'));
    });
  });
}
