import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/pot_stock.dart';

void main() {
  // ==================== PotStock.fromJson ====================

  group('PotStock.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': 'pot1',
        'diameterCm': 14.5,
        'quantity': 3,
        'label': 'Terre cuite',
        'createdAt': '2026-01-10T10:00:00Z',
        'updatedAt': '2026-03-01T15:00:00Z',
      };
      final pot = PotStock.fromJson(json);
      expect(pot.id, 'pot1');
      expect(pot.diameterCm, 14.5);
      expect(pot.quantity, 3);
      expect(pot.label, 'Terre cuite');
      expect(pot.createdAt, isNotNull);
      expect(pot.updatedAt, isNotNull);
    });

    test('defaults quantity to 0 when null', () {
      final json = {
        'id': 'pot2',
        'diameterCm': 10.0,
        'quantity': null,
      };
      final pot = PotStock.fromJson(json);
      expect(pot.quantity, 0);
    });

    test('handles null label', () {
      final json = {
        'id': 'pot3',
        'diameterCm': 8.0,
        'quantity': 1,
      };
      final pot = PotStock.fromJson(json);
      expect(pot.label, isNull);
    });

    test('handles null dates', () {
      final json = {
        'id': 'pot4',
        'diameterCm': 12.0,
        'quantity': 2,
      };
      final pot = PotStock.fromJson(json);
      expect(pot.createdAt, isNull);
      expect(pot.updatedAt, isNull);
    });

    test('handles int diameterCm as num', () {
      final json = {
        'id': 'pot5',
        'diameterCm': 20,
        'quantity': 1,
      };
      final pot = PotStock.fromJson(json);
      expect(pot.diameterCm, 20.0);
    });

    test('handles zero quantity', () {
      final json = {
        'id': 'pot6',
        'diameterCm': 10.0,
        'quantity': 0,
      };
      final pot = PotStock.fromJson(json);
      expect(pot.quantity, 0);
    });
  });

  // ==================== PotStock.displayText ====================

  group('PotStock.displayText', () {
    test('formats whole diameter without decimal', () {
      final pot = PotStock(id: '1', diameterCm: 14.0, quantity: 3);
      expect(pot.displayText, '14 cm (x3)');
    });

    test('formats fractional diameter with one decimal', () {
      final pot = PotStock(id: '1', diameterCm: 14.5, quantity: 2);
      expect(pot.displayText, '14.5 cm (x2)');
    });

    test('appends label when present', () {
      final pot = PotStock(id: '1', diameterCm: 10.0, quantity: 1, label: 'Plastique');
      expect(pot.displayText, '10 cm (x1) - Plastique');
    });

    test('no label part when label is null', () {
      final pot = PotStock(id: '1', diameterCm: 10.0, quantity: 1);
      expect(pot.displayText, '10 cm (x1)');
    });

    test('no label part when label is empty', () {
      final pot = PotStock(id: '1', diameterCm: 10.0, quantity: 1, label: '');
      expect(pot.displayText, '10 cm (x1)');
    });

    test('handles zero quantity', () {
      final pot = PotStock(id: '1', diameterCm: 8.0, quantity: 0);
      expect(pot.displayText, '8 cm (x0)');
    });

    test('handles large diameter', () {
      final pot = PotStock(id: '1', diameterCm: 100.0, quantity: 1);
      expect(pot.displayText, '100 cm (x1)');
    });

    test('handles large quantity', () {
      final pot = PotStock(id: '1', diameterCm: 10.0, quantity: 999);
      expect(pot.displayText, '10 cm (x999)');
    });
  });

  // ==================== PotStock.sizeDisplay ====================

  group('PotStock.sizeDisplay', () {
    test('formats whole number without decimal', () {
      final pot = PotStock(id: '1', diameterCm: 20.0, quantity: 1);
      expect(pot.sizeDisplay, '20 cm');
    });

    test('formats fractional number with one decimal', () {
      final pot = PotStock(id: '1', diameterCm: 7.5, quantity: 1);
      expect(pot.sizeDisplay, '7.5 cm');
    });

    test('formats small diameter', () {
      final pot = PotStock(id: '1', diameterCm: 3.0, quantity: 1);
      expect(pot.sizeDisplay, '3 cm');
    });
  });

  // ==================== PotStock.isAvailable ====================

  group('PotStock.isAvailable', () {
    test('true when quantity > 0', () {
      final pot = PotStock(id: '1', diameterCm: 10.0, quantity: 1);
      expect(pot.isAvailable, isTrue);
    });

    test('false when quantity == 0', () {
      final pot = PotStock(id: '1', diameterCm: 10.0, quantity: 0);
      expect(pot.isAvailable, isFalse);
    });

    test('true when quantity is large', () {
      final pot = PotStock(id: '1', diameterCm: 10.0, quantity: 100);
      expect(pot.isAvailable, isTrue);
    });
  });
}
