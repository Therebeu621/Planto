import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/plant.dart';
import 'package:planto/core/models/care_log.dart';

void main() {
  // ==================== Plant.fromJson ====================

  group('Plant.fromJson', () {
    test('parses complete JSON with all fields', () {
      final json = {
        'id': 'p1',
        'nickname': 'Monstera',
        'photoUrl': 'https://example.com/photo.jpg',
        'speciesCommonName': 'Monstera deliciosa',
        'needsWatering': true,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': true,
        'exposure': 'PARTIAL_SHADE',
        'wateringIntervalDays': 7,
        'lastWatered': '2026-03-01T10:00:00Z',
        'nextWateringDate': '2026-03-08T10:00:00Z',
        'notes': 'Likes humidity',
        'potDiameterCm': 15.5,
        'roomId': 'r1',
        'roomName': 'Salon',
        'acquiredAt': '2025-01-15T00:00:00Z',
        'createdAt': '2025-01-15T00:00:00Z',
      };

      final plant = Plant.fromJson(json);
      expect(plant.id, 'p1');
      expect(plant.nickname, 'Monstera');
      expect(plant.photoUrl, 'https://example.com/photo.jpg');
      expect(plant.speciesCommonName, 'Monstera deliciosa');
      expect(plant.needsWatering, isTrue);
      expect(plant.isSick, isFalse);
      expect(plant.isWilted, isFalse);
      expect(plant.needsRepotting, isTrue);
      expect(plant.exposure, 'PARTIAL_SHADE');
      expect(plant.wateringIntervalDays, 7);
      expect(plant.lastWatered, isNotNull);
      expect(plant.nextWateringDate, isNotNull);
      expect(plant.notes, 'Likes humidity');
      expect(plant.potDiameterCm, 15.5);
      expect(plant.roomId, 'r1');
      expect(plant.roomName, 'Salon');
      expect(plant.acquiredAt, isNotNull);
      expect(plant.createdAt, isNotNull);
    });

    test('defaults nickname to Sans nom when null', () {
      final json = {
        'id': 'p2',
        'nickname': null,
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
      };
      final plant = Plant.fromJson(json);
      expect(plant.nickname, 'Sans nom');
    });

    test('defaults boolean fields to false when null', () {
      final json = {
        'id': 'p3',
        'nickname': 'Test',
      };
      final plant = Plant.fromJson(json);
      expect(plant.needsWatering, isFalse);
      expect(plant.isSick, isFalse);
      expect(plant.isWilted, isFalse);
      expect(plant.needsRepotting, isFalse);
    });

    test('handles null optional fields gracefully', () {
      final json = {
        'id': 'p4',
        'nickname': 'Minimal',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
      };
      final plant = Plant.fromJson(json);
      expect(plant.photoUrl, isNull);
      expect(plant.speciesCommonName, isNull);
      expect(plant.exposure, isNull);
      expect(plant.wateringIntervalDays, isNull);
      expect(plant.lastWatered, isNull);
      expect(plant.nextWateringDate, isNull);
      expect(plant.notes, isNull);
      expect(plant.potDiameterCm, isNull);
      expect(plant.roomId, isNull);
      expect(plant.roomName, isNull);
      expect(plant.acquiredAt, isNull);
      expect(plant.createdAt, isNull);
      expect(plant.species, isNull);
      expect(plant.room, isNull);
      expect(plant.recentCareLogs, isEmpty);
    });

    test('parses nested room info', () {
      final json = {
        'id': 'p5',
        'nickname': 'Ficus',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
        'room': {
          'id': 'room1',
          'name': 'Chambre',
          'type': 'BEDROOM',
        },
      };
      final plant = Plant.fromJson(json);
      expect(plant.room, isNotNull);
      expect(plant.room!.id, 'room1');
      expect(plant.room!.name, 'Chambre');
      expect(plant.room!.type, 'BEDROOM');
      expect(plant.roomId, 'room1');
      expect(plant.roomName, 'Chambre');
    });

    test('parses nested species info', () {
      final json = {
        'id': 'p6',
        'nickname': 'Aloe',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
        'species': {
          'id': 'sp1',
          'trefleId': 12345,
          'commonName': 'Aloe Vera',
          'scientificName': 'Aloe barbadensis',
          'family': 'Asphodelaceae',
          'genus': 'Aloe',
          'imageUrl': 'https://example.com/aloe.jpg',
        },
      };
      final plant = Plant.fromJson(json);
      expect(plant.species, isNotNull);
      expect(plant.species!.commonName, 'Aloe Vera');
      expect(plant.species!.scientificName, 'Aloe barbadensis');
      expect(plant.species!.family, 'Asphodelaceae');
      expect(plant.speciesCommonName, 'Aloe Vera');
    });

    test('parses recent care logs', () {
      final json = {
        'id': 'p7',
        'nickname': 'Cactus',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
        'recentCareLogs': [
          {
            'id': 'cl1',
            'action': 'WATERING',
            'performedAt': '2026-03-10T08:00:00Z',
          },
          {
            'id': 'cl2',
            'action': 'FERTILIZING',
            'notes': 'Spring feeding',
            'performedAt': '2026-03-05T10:00:00Z',
          },
        ],
      };
      final plant = Plant.fromJson(json);
      expect(plant.recentCareLogs.length, 2);
      expect(plant.recentCareLogs[0].action, 'WATERING');
      expect(plant.recentCareLogs[1].notes, 'Spring feeding');
    });

    test('prepends base URL for relative photo paths', () {
      final json = {
        'id': 'p8',
        'nickname': 'RelPhoto',
        'photoUrl': '/api/v1/files/plants/photo.jpg',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
      };
      final plant = Plant.fromJson(json);
      expect(plant.photoUrl, isNotNull);
      expect(plant.photoUrl!.contains('/api/v1/files/plants/photo.jpg'), isTrue);
    });

    test('keeps absolute URLs as-is for photos', () {
      final json = {
        'id': 'p9',
        'nickname': 'AbsPhoto',
        'photoUrl': 'https://cdn.example.com/photo.jpg',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
      };
      final plant = Plant.fromJson(json);
      expect(plant.photoUrl, 'https://cdn.example.com/photo.jpg');
    });

    test('handles empty photoUrl string', () {
      final json = {
        'id': 'p10',
        'nickname': 'EmptyPhoto',
        'photoUrl': '',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
      };
      final plant = Plant.fromJson(json);
      expect(plant.photoUrl, isNull);
    });

    test('roomId falls back to room.id', () {
      final json = {
        'id': 'p11',
        'nickname': 'Fallback',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
        'room': {'id': 'r99', 'name': 'Kitchen', 'type': 'KITCHEN'},
      };
      final plant = Plant.fromJson(json);
      expect(plant.roomId, 'r99');
    });

    test('potDiameterCm handles int as num', () {
      final json = {
        'id': 'p12',
        'nickname': 'IntPot',
        'needsWatering': false,
        'isSick': false,
        'isWilted': false,
        'needsRepotting': false,
        'potDiameterCm': 14,
      };
      final plant = Plant.fromJson(json);
      expect(plant.potDiameterCm, 14.0);
    });
  });

  // ==================== COMPUTED PROPERTIES ====================

  group('Plant.exposureDisplay', () {
    Plant makePlant({String? exposure}) => Plant(
          id: '1',
          nickname: 'Test',
          needsWatering: false,
          isSick: false,
          isWilted: false,
          needsRepotting: false,
          exposure: exposure,
        );

    test('returns Plein soleil for SUN', () {
      expect(makePlant(exposure: 'SUN').exposureDisplay, 'Plein soleil');
    });

    test('returns Ombre for SHADE', () {
      expect(makePlant(exposure: 'SHADE').exposureDisplay, 'Ombre');
    });

    test('returns Mi-ombre for PARTIAL_SHADE', () {
      expect(makePlant(exposure: 'PARTIAL_SHADE').exposureDisplay, 'Mi-ombre');
    });

    test('returns Non defini for null', () {
      expect(makePlant(exposure: null).exposureDisplay, 'Non defini');
    });

    test('returns Non defini for unknown value', () {
      expect(makePlant(exposure: 'UNKNOWN').exposureDisplay, 'Non defini');
    });
  });

  group('Plant.healthStatus', () {
    test('returns Malade when sick', () {
      final plant = Plant(
        id: '1', nickname: 'T', needsWatering: false,
        isSick: true, isWilted: false, needsRepotting: false,
      );
      expect(plant.healthStatus, 'Malade');
    });

    test('returns Fanee when wilted', () {
      final plant = Plant(
        id: '1', nickname: 'T', needsWatering: false,
        isSick: false, isWilted: true, needsRepotting: false,
      );
      expect(plant.healthStatus, 'Fanee');
    });

    test('returns A rempoter when needs repotting', () {
      final plant = Plant(
        id: '1', nickname: 'T', needsWatering: false,
        isSick: false, isWilted: false, needsRepotting: true,
      );
      expect(plant.healthStatus, 'A rempoter');
    });

    test('returns A arroser when needs watering', () {
      final plant = Plant(
        id: '1', nickname: 'T', needsWatering: true,
        isSick: false, isWilted: false, needsRepotting: false,
      );
      expect(plant.healthStatus, 'A arroser');
    });

    test('returns En forme when healthy', () {
      final plant = Plant(
        id: '1', nickname: 'T', needsWatering: false,
        isSick: false, isWilted: false, needsRepotting: false,
      );
      expect(plant.healthStatus, 'En forme');
    });

    test('sick takes priority over wilted', () {
      final plant = Plant(
        id: '1', nickname: 'T', needsWatering: true,
        isSick: true, isWilted: true, needsRepotting: true,
      );
      expect(plant.healthStatus, 'Malade');
    });
  });

  group('Plant.hasHealthIssues', () {
    test('true when sick', () {
      final p = Plant(id: '1', nickname: 'T', needsWatering: false, isSick: true, isWilted: false, needsRepotting: false);
      expect(p.hasHealthIssues, isTrue);
    });

    test('true when wilted', () {
      final p = Plant(id: '1', nickname: 'T', needsWatering: false, isSick: false, isWilted: true, needsRepotting: false);
      expect(p.hasHealthIssues, isTrue);
    });

    test('true when needs repotting', () {
      final p = Plant(id: '1', nickname: 'T', needsWatering: false, isSick: false, isWilted: false, needsRepotting: true);
      expect(p.hasHealthIssues, isTrue);
    });

    test('false when all healthy', () {
      final p = Plant(id: '1', nickname: 'T', needsWatering: false, isSick: false, isWilted: false, needsRepotting: false);
      expect(p.hasHealthIssues, isFalse);
    });

    test('needsWatering alone is not a health issue', () {
      final p = Plant(id: '1', nickname: 'T', needsWatering: true, isSick: false, isWilted: false, needsRepotting: false);
      expect(p.hasHealthIssues, isFalse);
    });
  });

  group('Plant.potSizeDisplay', () {
    Plant makePlant({double? diameter}) => Plant(
          id: '1', nickname: 'T', needsWatering: false,
          isSick: false, isWilted: false, needsRepotting: false,
          potDiameterCm: diameter,
        );

    test('returns Non defini for null', () {
      expect(makePlant(diameter: null).potSizeDisplay, 'Non defini');
    });

    test('returns integer format for whole numbers', () {
      expect(makePlant(diameter: 14.0).potSizeDisplay, '14 cm');
    });

    test('returns decimal format for fractional numbers', () {
      expect(makePlant(diameter: 15.5).potSizeDisplay, '15.5 cm');
    });

    test('returns integer format for x.0 values', () {
      expect(makePlant(diameter: 20.0).potSizeDisplay, '20 cm');
    });
  });

  group('Plant.wateringStatusText', () {
    Plant makePlant({DateTime? nextWatering}) => Plant(
          id: '1', nickname: 'T', needsWatering: false,
          isSick: false, isWilted: false, needsRepotting: false,
          nextWateringDate: nextWatering,
        );

    test('returns Non programme for null date', () {
      expect(makePlant(nextWatering: null).wateringStatusText, 'Non programme');
    });

    test('returns A arroser demain for tomorrow', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 23, 59);
      expect(makePlant(nextWatering: tomorrow).wateringStatusText, 'A arroser demain');
    });

    test('returns Dans X jours for future dates', () {
      final now = DateTime.now();
      final future = DateTime(now.year, now.month, now.day + 5, 23, 59);
      expect(makePlant(nextWatering: future).wateringStatusText, 'Dans 5 jours');
    });

    test('returns overdue text for past dates', () {
      final past = DateTime.now().subtract(const Duration(days: 3));
      final text = makePlant(nextWatering: past).wateringStatusText;
      expect(text, contains('retard'));
    });
  });

  group('Plant.daysUntilWatering', () {
    test('returns null when no next watering date', () {
      final p = Plant(id: '1', nickname: 'T', needsWatering: false, isSick: false, isWilted: false, needsRepotting: false);
      expect(p.daysUntilWatering, isNull);
    });

    test('returns positive for future dates', () {
      final p = Plant(
        id: '1', nickname: 'T', needsWatering: false,
        isSick: false, isWilted: false, needsRepotting: false,
        nextWateringDate: DateTime.now().add(const Duration(days: 10)),
      );
      expect(p.daysUntilWatering, greaterThanOrEqualTo(9));
    });

    test('returns negative for past dates', () {
      final p = Plant(
        id: '1', nickname: 'T', needsWatering: false,
        isSick: false, isWilted: false, needsRepotting: false,
        nextWateringDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(p.daysUntilWatering, lessThan(0));
    });
  });

  // ==================== SpeciesInfo ====================

  group('SpeciesInfo.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': 'sp1',
        'trefleId': 42,
        'commonName': 'Rose',
        'scientificName': 'Rosa',
        'family': 'Rosaceae',
        'genus': 'Rosa',
        'imageUrl': 'https://img.com/rose.jpg',
      };
      final s = SpeciesInfo.fromJson(json);
      expect(s.id, 'sp1');
      expect(s.trefleId, 42);
      expect(s.commonName, 'Rose');
      expect(s.scientificName, 'Rosa');
      expect(s.family, 'Rosaceae');
      expect(s.genus, 'Rosa');
      expect(s.imageUrl, 'https://img.com/rose.jpg');
    });

    test('handles all null optional fields', () {
      final json = <String, dynamic>{};
      final s = SpeciesInfo.fromJson(json);
      expect(s.id, isNull);
      expect(s.trefleId, isNull);
      expect(s.commonName, isNull);
    });
  });

  // ==================== RoomInfo ====================

  group('RoomInfo.fromJson', () {
    test('parses complete JSON', () {
      final json = {'id': 'r1', 'name': 'Salon', 'type': 'LIVING_ROOM'};
      final r = RoomInfo.fromJson(json);
      expect(r.id, 'r1');
      expect(r.name, 'Salon');
      expect(r.type, 'LIVING_ROOM');
    });

    test('handles null type', () {
      final json = {'id': 'r2', 'name': 'Room'};
      final r = RoomInfo.fromJson(json);
      expect(r.type, isNull);
    });
  });

  group('RoomInfo.icon', () {
    test('returns correct icons for all types', () {
      expect(RoomInfo(id: '1', name: 'R', type: 'LIVING_ROOM').icon, '🛋️');
      expect(RoomInfo(id: '1', name: 'R', type: 'BEDROOM').icon, '🛏️');
      expect(RoomInfo(id: '1', name: 'R', type: 'BALCONY').icon, '🌿');
      expect(RoomInfo(id: '1', name: 'R', type: 'GARDEN').icon, '🏡');
      expect(RoomInfo(id: '1', name: 'R', type: 'KITCHEN').icon, '🍳');
      expect(RoomInfo(id: '1', name: 'R', type: 'BATHROOM').icon, '🚿');
      expect(RoomInfo(id: '1', name: 'R', type: 'OFFICE').icon, '💼');
      expect(RoomInfo(id: '1', name: 'R', type: 'OTHER').icon, '🏠');
      expect(RoomInfo(id: '1', name: 'R', type: null).icon, '🏠');
    });
  });
}
