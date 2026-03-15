import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/room.dart';

void main() {
  // ==================== Room.fromJson ====================

  group('Room.fromJson', () {
    test('parses complete JSON with plants', () {
      final json = {
        'id': 'r1',
        'name': 'Salon',
        'type': 'LIVING_ROOM',
        'plantCount': 3,
        'plants': [
          {
            'id': 'p1',
            'nickname': 'Monstera',
            'needsWatering': true,
            'healthStatus': 'GOOD',
          },
          {
            'id': 'p2',
            'nickname': 'Ficus',
            'needsWatering': false,
            'healthStatus': 'SICK',
          },
        ],
      };
      final room = Room.fromJson(json);
      expect(room.id, 'r1');
      expect(room.name, 'Salon');
      expect(room.type, 'LIVING_ROOM');
      expect(room.plantCount, 3);
      expect(room.plants.length, 2);
    });

    test('defaults type to OTHER when null', () {
      final json = {
        'id': 'r2',
        'name': 'Room',
        'type': null,
        'plantCount': 0,
        'plants': [],
      };
      final room = Room.fromJson(json);
      expect(room.type, 'OTHER');
    });

    test('defaults plantCount to 0 when null', () {
      final json = {
        'id': 'r3',
        'name': 'Room',
        'type': 'BEDROOM',
        'plantCount': null,
      };
      final room = Room.fromJson(json);
      expect(room.plantCount, 0);
    });

    test('handles missing plants list', () {
      final json = {
        'id': 'r4',
        'name': 'Room',
        'type': 'OFFICE',
        'plantCount': 0,
      };
      final room = Room.fromJson(json);
      expect(room.plants, isEmpty);
    });

    test('handles empty plants list', () {
      final json = {
        'id': 'r5',
        'name': 'Room',
        'type': 'OFFICE',
        'plantCount': 0,
        'plants': [],
      };
      final room = Room.fromJson(json);
      expect(room.plants, isEmpty);
    });
  });

  // ==================== Room.typeDisplay ====================

  group('Room.typeDisplay', () {
    Room makeRoom(String type) => Room(
          id: '1', name: 'R', type: type, plantCount: 0, plants: [],
        );

    test('LIVING_ROOM -> Salon', () {
      expect(makeRoom('LIVING_ROOM').typeDisplay, 'Salon');
    });

    test('BEDROOM -> Chambre', () {
      expect(makeRoom('BEDROOM').typeDisplay, 'Chambre');
    });

    test('BALCONY -> Balcon', () {
      expect(makeRoom('BALCONY').typeDisplay, 'Balcon');
    });

    test('GARDEN -> Jardin', () {
      expect(makeRoom('GARDEN').typeDisplay, 'Jardin');
    });

    test('KITCHEN -> Cuisine', () {
      expect(makeRoom('KITCHEN').typeDisplay, 'Cuisine');
    });

    test('BATHROOM -> Salle de bain', () {
      expect(makeRoom('BATHROOM').typeDisplay, 'Salle de bain');
    });

    test('OFFICE -> Bureau', () {
      expect(makeRoom('OFFICE').typeDisplay, 'Bureau');
    });

    test('OTHER -> Autre', () {
      expect(makeRoom('OTHER').typeDisplay, 'Autre');
    });

    test('unknown type -> Autre', () {
      expect(makeRoom('UNKNOWN').typeDisplay, 'Autre');
    });
  });

  // ==================== Room.icon ====================

  group('Room.icon', () {
    Room makeRoom(String type) => Room(
          id: '1', name: 'R', type: type, plantCount: 0, plants: [],
        );

    test('returns correct emoji for each type', () {
      expect(makeRoom('LIVING_ROOM').icon, '🛋️');
      expect(makeRoom('BEDROOM').icon, '🛏️');
      expect(makeRoom('BALCONY').icon, '🌿');
      expect(makeRoom('GARDEN').icon, '🌳');
      expect(makeRoom('KITCHEN').icon, '🍳');
      expect(makeRoom('BATHROOM').icon, '🚿');
      expect(makeRoom('OFFICE').icon, '💼');
      expect(makeRoom('OTHER').icon, '🏠');
    });

    test('returns default emoji for unknown type', () {
      expect(makeRoom('UNKNOWN_TYPE').icon, '🏠');
    });
  });

  // ==================== PlantSummary.fromJson ====================

  group('PlantSummary.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': 'ps1',
        'nickname': 'My Plant',
        'photoUrl': 'https://example.com/photo.jpg',
        'speciesCommonName': 'Rose',
        'needsWatering': true,
        'nextWateringDate': '2026-03-15T00:00:00Z',
        'isSick': false,
        'isWilted': false,
        'needsRepotting': true,
        'healthStatus': 'GOOD',
      };
      final ps = PlantSummary.fromJson(json);
      expect(ps.id, 'ps1');
      expect(ps.nickname, 'My Plant');
      expect(ps.speciesCommonName, 'Rose');
      expect(ps.needsWatering, isTrue);
      expect(ps.needsRepotting, isTrue);
      expect(ps.isSick, isFalse);
      expect(ps.isWilted, isFalse);
      expect(ps.nextWateringDate, isNotNull);
    });

    test('defaults nickname to Sans nom', () {
      final json = {
        'id': 'ps2',
        'nickname': null,
        'needsWatering': false,
        'healthStatus': 'GOOD',
      };
      final ps = PlantSummary.fromJson(json);
      expect(ps.nickname, 'Sans nom');
    });

    test('falls back to healthStatus string for isSick', () {
      final json = {
        'id': 'ps3',
        'nickname': 'Sick Plant',
        'needsWatering': false,
        'healthStatus': 'SICK',
      };
      final ps = PlantSummary.fromJson(json);
      expect(ps.isSick, isTrue);
    });

    test('falls back to healthStatus string for isWilted', () {
      final json = {
        'id': 'ps4',
        'nickname': 'Wilted Plant',
        'needsWatering': false,
        'healthStatus': 'WILTED',
      };
      final ps = PlantSummary.fromJson(json);
      expect(ps.isWilted, isTrue);
    });

    test('direct booleans override healthStatus fallback', () {
      final json = {
        'id': 'ps5',
        'nickname': 'Override',
        'needsWatering': false,
        'isSick': true,
        'healthStatus': 'GOOD',
      };
      final ps = PlantSummary.fromJson(json);
      expect(ps.isSick, isTrue);
    });

    test('handles relative photo URL', () {
      final json = {
        'id': 'ps6',
        'nickname': 'RelPhoto',
        'photoUrl': '/api/v1/files/img.png',
        'needsWatering': false,
        'healthStatus': 'GOOD',
      };
      final ps = PlantSummary.fromJson(json);
      expect(ps.photoUrl, isNotNull);
      expect(ps.photoUrl!.contains('/api/v1/files/img.png'), isTrue);
    });

    test('handles empty photo URL', () {
      final json = {
        'id': 'ps7',
        'nickname': 'EmptyUrl',
        'photoUrl': '',
        'needsWatering': false,
        'healthStatus': 'GOOD',
      };
      final ps = PlantSummary.fromJson(json);
      expect(ps.photoUrl, isNull);
    });
  });

  group('PlantSummary.daysUntilWatering', () {
    test('returns 0 when no next watering date', () {
      final ps = PlantSummary(id: '1', nickname: 'T', needsWatering: false);
      expect(ps.daysUntilWatering, 0);
    });

    test('returns positive for future date', () {
      final ps = PlantSummary(
        id: '1',
        nickname: 'T',
        needsWatering: false,
        nextWateringDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(ps.daysUntilWatering, greaterThanOrEqualTo(4));
    });

    test('returns negative for past date', () {
      final ps = PlantSummary(
        id: '1',
        nickname: 'T',
        needsWatering: false,
        nextWateringDate: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(ps.daysUntilWatering, lessThan(0));
    });
  });

  group('PlantSummary.isUrgent', () {
    test('true when overdue', () {
      final ps = PlantSummary(
        id: '1', nickname: 'T', needsWatering: true,
        nextWateringDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(ps.isUrgent, isTrue);
    });

    test('true when due today', () {
      final ps = PlantSummary(
        id: '1', nickname: 'T', needsWatering: true,
        nextWateringDate: DateTime.now(),
      );
      expect(ps.isUrgent, isTrue);
    });

    test('false when due in future', () {
      final ps = PlantSummary(
        id: '1', nickname: 'T', needsWatering: false,
        nextWateringDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(ps.isUrgent, isFalse);
    });

    test('true when no date (defaults to 0)', () {
      final ps = PlantSummary(id: '1', nickname: 'T', needsWatering: false);
      expect(ps.isUrgent, isTrue);
    });
  });
}
