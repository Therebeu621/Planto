import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/plant_identification_result.dart';

void main() {
  // ==================== PlantIdentificationResult.fromJson ====================

  group('PlantIdentificationResult.fromJson', () {
    test('parses complete JSON from Gemini', () {
      final json = {
        'petit_nom': 'Petite Monstera',
        'espece': 'Monstera deliciosa',
        'arrosage_jours': 7,
        'luminosite': 'Mi-ombre',
        'description': 'Grande plante tropicale',
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.petitNom, 'Petite Monstera');
      expect(result.espece, 'Monstera deliciosa');
      expect(result.arrosageJours, 7);
      expect(result.luminosite, 'Mi-ombre');
      expect(result.description, 'Grande plante tropicale');
    });

    test('defaults petitNom to Ma plante when null', () {
      final json = {
        'petit_nom': null,
        'espece': 'Test',
        'arrosage_jours': 5,
        'luminosite': 'Ombre',
        'description': 'Desc',
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.petitNom, 'Ma plante');
    });

    test('defaults espece to Espece inconnue when null', () {
      final json = {
        'petit_nom': 'Name',
        'espece': null,
        'arrosage_jours': 5,
        'luminosite': 'Ombre',
        'description': 'Desc',
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.espece, 'Espece inconnue');
    });

    test('defaults arrosageJours to 7 when null', () {
      final json = {
        'petit_nom': 'Name',
        'espece': 'Species',
        'arrosage_jours': null,
        'luminosite': 'Ombre',
        'description': 'Desc',
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.arrosageJours, 7);
    });

    test('defaults luminosite to Mi-ombre when null', () {
      final json = {
        'petit_nom': 'Name',
        'espece': 'Species',
        'arrosage_jours': 5,
        'luminosite': null,
        'description': 'Desc',
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.luminosite, 'Mi-ombre');
    });

    test('defaults description to empty string when null', () {
      final json = {
        'petit_nom': 'Name',
        'espece': 'Species',
        'arrosage_jours': 5,
        'luminosite': 'Ombre',
        'description': null,
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.description, '');
    });

    test('handles all null values with defaults', () {
      final json = <String, dynamic>{};
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.petitNom, 'Ma plante');
      expect(result.espece, 'Espece inconnue');
      expect(result.arrosageJours, 7);
      expect(result.luminosite, 'Mi-ombre');
      expect(result.description, '');
    });

    test('handles zero arrosage_jours', () {
      final json = {
        'petit_nom': 'Cactus',
        'espece': 'Cactaceae',
        'arrosage_jours': 0,
        'luminosite': 'Plein soleil',
        'description': 'Very low water needs',
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.arrosageJours, 0);
    });

    test('handles large arrosage_jours', () {
      final json = {
        'petit_nom': 'Desert Plant',
        'espece': 'Lithops',
        'arrosage_jours': 60,
        'luminosite': 'Plein soleil',
        'description': 'Rarely needs water',
      };
      final result = PlantIdentificationResult.fromJson(json);
      expect(result.arrosageJours, 60);
    });
  });

  // ==================== PlantIdentificationResult.exposureValue ====================

  group('PlantIdentificationResult.exposureValue', () {
    PlantIdentificationResult makeResult(String luminosite) =>
        PlantIdentificationResult(
          petitNom: 'T',
          espece: 'T',
          arrosageJours: 7,
          luminosite: luminosite,
          description: '',
        );

    test('Plein soleil -> SUN', () {
      expect(makeResult('Plein soleil').exposureValue, 'SUN');
    });

    test('plein soleil (lowercase) -> SUN', () {
      expect(makeResult('plein soleil').exposureValue, 'SUN');
    });

    test('PLEIN SOLEIL (uppercase) -> SUN', () {
      expect(makeResult('PLEIN SOLEIL').exposureValue, 'SUN');
    });

    test('Ombre -> SHADE', () {
      expect(makeResult('Ombre').exposureValue, 'SHADE');
    });

    test('ombre (lowercase) -> SHADE', () {
      expect(makeResult('ombre').exposureValue, 'SHADE');
    });

    test('Mi-ombre -> PARTIAL_SHADE', () {
      expect(makeResult('Mi-ombre').exposureValue, 'PARTIAL_SHADE');
    });

    test('mi-ombre (lowercase) -> PARTIAL_SHADE', () {
      expect(makeResult('mi-ombre').exposureValue, 'PARTIAL_SHADE');
    });

    test('unknown value defaults to PARTIAL_SHADE', () {
      expect(makeResult('unknown').exposureValue, 'PARTIAL_SHADE');
    });

    test('empty string defaults to PARTIAL_SHADE', () {
      expect(makeResult('').exposureValue, 'PARTIAL_SHADE');
    });
  });

  // ==================== PlantIdentificationResult.toString ====================

  group('PlantIdentificationResult.toString', () {
    test('includes all main fields', () {
      final result = PlantIdentificationResult(
        petitNom: 'Mon Aloe',
        espece: 'Aloe vera',
        arrosageJours: 14,
        luminosite: 'Plein soleil',
        description: 'Desert succulent',
      );
      final str = result.toString();
      expect(str, contains('Mon Aloe'));
      expect(str, contains('Aloe vera'));
      expect(str, contains('14'));
      expect(str, contains('Plein soleil'));
    });
  });
}
