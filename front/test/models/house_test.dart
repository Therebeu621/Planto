import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/house.dart';

void main() {
  // ==================== FACTORY / DESERIALIZATION ====================

  group('House.fromJson', () {
    test('parses complete JSON with OWNER role', () {
      final json = {
        'id': 'h1',
        'name': 'Ma Maison',
        'inviteCode': 'ABC123',
        'memberCount': 3,
        'roomCount': 5,
        'isActive': true,
        'role': 'OWNER',
      };
      final house = House.fromJson(json);
      expect(house.id, 'h1');
      expect(house.name, 'Ma Maison');
      expect(house.inviteCode, 'ABC123');
      expect(house.memberCount, 3);
      expect(house.roomCount, 5);
      expect(house.isActive, isTrue);
      expect(house.role, 'OWNER');
      expect(house.isOwner, isTrue);
    });

    test('parses JSON with MEMBER role', () {
      final json = {
        'id': 'h2',
        'name': 'House 2',
        'inviteCode': 'DEF456',
        'memberCount': 2,
        'roomCount': 1,
        'isActive': false,
        'role': 'MEMBER',
      };
      final house = House.fromJson(json);
      expect(house.role, 'MEMBER');
      expect(house.isOwner, isFalse);
    });

    test('parses JSON with GUEST role', () {
      final json = {
        'id': 'h3',
        'name': 'Guest House',
        'inviteCode': 'GHI789',
        'memberCount': 4,
        'roomCount': 2,
        'isActive': true,
        'role': 'GUEST',
      };
      final house = House.fromJson(json);
      expect(house.role, 'GUEST');
      expect(house.isOwner, isFalse);
    });

    test('role is null when missing from JSON', () {
      final json = {
        'id': 'h4',
        'name': 'No Role House',
        'inviteCode': 'JKL012',
        'memberCount': 1,
        'roomCount': 0,
        'isActive': false,
      };
      final house = House.fromJson(json);
      expect(house.role, isNull);
      expect(house.isOwner, isFalse);
    });

    test('defaults name to Sans nom when null', () {
      final json = {
        'id': 'h5',
        'name': null,
        'inviteCode': 'XYZ',
        'memberCount': 0,
        'roomCount': 0,
        'isActive': false,
      };
      final house = House.fromJson(json);
      expect(house.name, 'Sans nom');
    });

    test('defaults memberCount to 0 when null', () {
      final json = {
        'id': 'h6',
        'name': 'House',
        'inviteCode': '',
        'memberCount': null,
        'roomCount': null,
        'isActive': null,
      };
      final house = House.fromJson(json);
      expect(house.memberCount, 0);
      expect(house.roomCount, 0);
      expect(house.isActive, isFalse);
    });

    test('defaults inviteCode to empty string when null', () {
      final json = {
        'id': 'h7',
        'name': 'House',
        'inviteCode': null,
        'memberCount': 0,
        'roomCount': 0,
        'isActive': false,
      };
      final house = House.fromJson(json);
      expect(house.inviteCode, '');
    });
  });

  // ==================== isOwner ====================

  group('House.isOwner', () {
    test('is true only for OWNER role', () {
      final owner = House(id: '1', name: 'H', inviteCode: '', memberCount: 0, roomCount: 0, isActive: true, role: 'OWNER');
      final member = House(id: '2', name: 'H', inviteCode: '', memberCount: 0, roomCount: 0, isActive: true, role: 'MEMBER');
      final guest = House(id: '3', name: 'H', inviteCode: '', memberCount: 0, roomCount: 0, isActive: true, role: 'GUEST');
      final noRole = House(id: '4', name: 'H', inviteCode: '', memberCount: 0, roomCount: 0, isActive: true);

      expect(owner.isOwner, isTrue);
      expect(member.isOwner, isFalse);
      expect(guest.isOwner, isFalse);
      expect(noRole.isOwner, isFalse);
    });

    test('is case-sensitive', () {
      final lower = House(id: '5', name: 'H', inviteCode: '', memberCount: 0, roomCount: 0, isActive: true, role: 'owner');
      expect(lower.isOwner, isFalse);
    });
  });
}
