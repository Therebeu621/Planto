import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/species.dart';

void main() {
  // ==================== Species.fromJson ====================

  group('Species.fromJson', () {
    test('parses complete JSON with UUID id', () {
      final json = {
        'id': 'abc-123',
        'trefleId': 42,
        'commonName': 'Monstera',
        'scientificName': 'Monstera deliciosa',
        'family': 'Araceae',
        'genus': 'Monstera',
        'imageUrl': 'https://img.com/monstera.jpg',
      };
      final s = Species.fromJson(json);
      expect(s.id, 'abc-123');
      expect(s.trefleId, 42);
      expect(s.commonName, 'Monstera');
      expect(s.scientificName, 'Monstera deliciosa');
      expect(s.family, 'Araceae');
      expect(s.genus, 'Monstera');
      expect(s.imageUrl, 'https://img.com/monstera.jpg');
    });

    test('uses perenual_ prefix when id is null but trefleId exists', () {
      final json = {
        'id': null,
        'trefleId': 999,
        'commonName': 'Perenual Plant',
      };
      final s = Species.fromJson(json);
      expect(s.id, 'perenual_999');
    });

    test('generates unknown_ id when both id and trefleId are null', () {
      final json = {
        'commonName': 'Mystery Plant',
      };
      final s = Species.fromJson(json);
      expect(s.id, startsWith('unknown_'));
    });

    test('defaults commonName to Espece inconnue when null', () {
      final json = {
        'id': 'x1',
        'commonName': null,
      };
      final s = Species.fromJson(json);
      expect(s.commonName, 'Espèce inconnue');
    });

    test('handles all null optional fields', () {
      final json = {'id': 'x2'};
      final s = Species.fromJson(json);
      expect(s.trefleId, isNull);
      expect(s.scientificName, isNull);
      expect(s.family, isNull);
      expect(s.genus, isNull);
      expect(s.imageUrl, isNull);
    });

    test('handles missing id with trefleId as int', () {
      final json = {'trefleId': 0, 'commonName': 'Zero ID'};
      final s = Species.fromJson(json);
      expect(s.id, 'perenual_0');
    });
  });

  // ==================== Species.displayName ====================

  group('Species.displayName', () {
    test('includes scientific name in parentheses when available', () {
      final s = Species(id: '1', commonName: 'Aloe', scientificName: 'Aloe vera');
      expect(s.displayName, 'Aloe (Aloe vera)');
    });

    test('returns only common name when scientific name is null', () {
      final s = Species(id: '1', commonName: 'Cactus');
      expect(s.displayName, 'Cactus');
    });

    test('returns only common name when scientific name is empty', () {
      final s = Species(id: '1', commonName: 'Fern', scientificName: '');
      expect(s.displayName, 'Fern');
    });

    test('handles long names gracefully', () {
      final s = Species(
        id: '1',
        commonName: 'Very Long Common Name Plant',
        scientificName: 'Plantus longissimus extremus',
      );
      expect(s.displayName, 'Very Long Common Name Plant (Plantus longissimus extremus)');
    });
  });
}
