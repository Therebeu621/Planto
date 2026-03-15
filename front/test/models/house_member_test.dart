import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/house_member.dart';

void main() {
  // ==================== FACTORY / DESERIALIZATION ====================

  group('HouseMember.fromJson', () {
    test('parses OWNER role correctly', () {
      final json = {
        'userId': 'u1',
        'displayName': 'Alice Owner',
        'email': 'alice@test.com',
        'role': 'OWNER',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.role, 'OWNER');
      expect(member.isOwner, isTrue);
      expect(member.isGuest, isFalse);
    });

    test('parses MEMBER role correctly', () {
      final json = {
        'userId': 'u2',
        'displayName': 'Bob Member',
        'email': 'bob@test.com',
        'role': 'MEMBER',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.role, 'MEMBER');
      expect(member.isOwner, isFalse);
      expect(member.isGuest, isFalse);
    });

    test('parses GUEST role correctly', () {
      final json = {
        'userId': 'u3',
        'displayName': 'Charlie Guest',
        'email': 'charlie@test.com',
        'role': 'GUEST',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.role, 'GUEST');
      expect(member.isOwner, isFalse);
      expect(member.isGuest, isTrue);
    });

    test('defaults to MEMBER when role is null', () {
      final json = {
        'userId': 'u4',
        'displayName': 'Dana',
        'email': 'dana@test.com',
        'role': null,
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.role, 'MEMBER');
      expect(member.isOwner, isFalse);
      expect(member.isGuest, isFalse);
    });

    test('defaults to MEMBER when role is missing from JSON', () {
      final json = {
        'userId': 'u5',
        'displayName': 'Eve',
        'email': 'eve@test.com',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.role, 'MEMBER');
    });

    test('handles missing displayName gracefully', () {
      final json = {
        'userId': 'u6',
        'email': 'nobody@test.com',
        'role': 'GUEST',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': false,
      };
      final member = HouseMember.fromJson(json);
      expect(member.displayName, 'Utilisateur');
    });

    test('handles missing email gracefully', () {
      final json = {
        'userId': 'u7',
        'displayName': 'No Email',
        'role': 'GUEST',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': false,
      };
      final member = HouseMember.fromJson(json);
      expect(member.email, '');
    });

    test('handles null joinedAt with fallback to now', () {
      final before = DateTime.now();
      final json = {
        'userId': 'u8',
        'displayName': 'Late Joiner',
        'email': 'late@test.com',
        'role': 'GUEST',
        'joinedAt': null,
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      final after = DateTime.now();
      expect(member.joinedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(member.joinedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('parses profilePhotoUrl field', () {
      final json = {
        'userId': 'u9',
        'displayName': 'Photo User',
        'email': 'photo@test.com',
        'profilePhotoUrl': '/photos/u9.jpg',
        'role': 'GUEST',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.profilePhotoPath, '/photos/u9.jpg');
    });

    test('parses profilePhotoPath field as fallback', () {
      final json = {
        'userId': 'u10',
        'displayName': 'Photo User 2',
        'email': 'photo2@test.com',
        'profilePhotoPath': '/photos/u10.jpg',
        'role': 'MEMBER',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.profilePhotoPath, '/photos/u10.jpg');
    });

    test('profilePhotoPath is null when both fields are absent', () {
      final json = {
        'userId': 'u11',
        'displayName': 'No Photo',
        'email': 'nophoto@test.com',
        'role': 'GUEST',
        'joinedAt': '2025-01-01T00:00:00Z',
        'isActive': true,
      };
      final member = HouseMember.fromJson(json);
      expect(member.profilePhotoPath, isNull);
    });
  });

  // ==================== ROLE DISPLAY NAME ====================

  group('HouseMember.roleDisplayName', () {
    HouseMember _makeMember({required String role}) {
      return HouseMember(
        id: 'test',
        displayName: 'Test',
        email: 'test@test.com',
        role: role,
        joinedAt: DateTime.now(),
        isActive: true,
      );
    }

    test('OWNER displays as Proprietaire', () {
      expect(_makeMember(role: 'OWNER').roleDisplayName, 'Proprietaire');
    });

    test('MEMBER displays as Membre', () {
      expect(_makeMember(role: 'MEMBER').roleDisplayName, 'Membre');
    });

    test('GUEST displays as Invite', () {
      expect(_makeMember(role: 'GUEST').roleDisplayName, 'Invite');
    });

    test('unknown role defaults to Membre', () {
      expect(_makeMember(role: 'ADMIN').roleDisplayName, 'Membre');
    });

    test('empty role defaults to Membre', () {
      expect(_makeMember(role: '').roleDisplayName, 'Membre');
    });
  });

  // ==================== BOOLEAN ROLE CHECKS ====================

  group('HouseMember role boolean checks', () {
    HouseMember _makeMember({required String role}) {
      return HouseMember(
        id: 'test',
        displayName: 'Test',
        email: 'test@test.com',
        role: role,
        joinedAt: DateTime.now(),
        isActive: true,
      );
    }

    test('isOwner is true only for OWNER', () {
      expect(_makeMember(role: 'OWNER').isOwner, isTrue);
      expect(_makeMember(role: 'MEMBER').isOwner, isFalse);
      expect(_makeMember(role: 'GUEST').isOwner, isFalse);
    });

    test('isGuest is true only for GUEST', () {
      expect(_makeMember(role: 'GUEST').isGuest, isTrue);
      expect(_makeMember(role: 'MEMBER').isGuest, isFalse);
      expect(_makeMember(role: 'OWNER').isGuest, isFalse);
    });

    test('MEMBER is neither owner nor guest', () {
      final member = _makeMember(role: 'MEMBER');
      expect(member.isOwner, isFalse);
      expect(member.isGuest, isFalse);
    });

    test('role check is case-sensitive (lowercase fails)', () {
      expect(_makeMember(role: 'owner').isOwner, isFalse);
      expect(_makeMember(role: 'guest').isGuest, isFalse);
    });
  });

  // ==================== INITIALS ====================

  group('HouseMember.initials', () {
    HouseMember _withName(String name) {
      return HouseMember(
        id: 'test',
        displayName: name,
        email: 'test@test.com',
        role: 'GUEST',
        joinedAt: DateTime.now(),
        isActive: true,
      );
    }

    test('two-word name returns both initials', () {
      expect(_withName('Alice Bob').initials, 'AB');
    });

    test('single-word name returns first letter', () {
      expect(_withName('Alice').initials, 'A');
    });

    test('three-word name returns first two initials', () {
      expect(_withName('Jean Pierre Dupont').initials, 'JP');
    });

    test('lowercase name returns uppercase initials', () {
      expect(_withName('alice bob').initials, 'AB');
    });

    test('empty name returns ?', () {
      expect(_withName('').initials, '?');
    });
  });
}
