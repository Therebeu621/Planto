import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/user_profile.dart';

void main() {
  // ==================== UserProfile.fromJson ====================

  group('UserProfile.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': 'u1',
        'email': 'test@example.com',
        'displayName': 'John Doe',
        'role': 'OWNER',
        'createdAt': '2025-06-15T10:00:00Z',
        'profilePhotoUrl': 'https://img.com/avatar.jpg',
        'emailVerified': true,
      };
      final p = UserProfile.fromJson(json);
      expect(p.id, 'u1');
      expect(p.email, 'test@example.com');
      expect(p.displayName, 'John Doe');
      expect(p.role, 'OWNER');
      expect(p.createdAt, isNotNull);
      expect(p.profilePhotoUrl, 'https://img.com/avatar.jpg');
      expect(p.emailVerified, isTrue);
    });

    test('defaults displayName to Utilisateur when null', () {
      final json = {
        'id': 'u2',
        'email': 'a@b.com',
        'displayName': null,
      };
      final p = UserProfile.fromJson(json);
      expect(p.displayName, 'Utilisateur');
    });

    test('defaults role to MEMBER when null', () {
      final json = {
        'id': 'u3',
        'email': 'a@b.com',
        'displayName': 'Test',
      };
      final p = UserProfile.fromJson(json);
      expect(p.role, 'MEMBER');
    });

    test('defaults emailVerified to false when null', () {
      final json = {
        'id': 'u4',
        'email': 'a@b.com',
      };
      final p = UserProfile.fromJson(json);
      expect(p.emailVerified, isFalse);
    });

    test('handles null createdAt', () {
      final json = {
        'id': 'u5',
        'email': 'a@b.com',
        'createdAt': null,
      };
      final p = UserProfile.fromJson(json);
      expect(p.createdAt, isNull);
    });

    test('handles null profilePhotoUrl', () {
      final json = {
        'id': 'u6',
        'email': 'a@b.com',
      };
      final p = UserProfile.fromJson(json);
      expect(p.profilePhotoUrl, isNull);
    });
  });

  // ==================== UserProfile.hasProfilePhoto ====================

  group('UserProfile.hasProfilePhoto', () {
    test('true when URL is set', () {
      final p = UserProfile(
        id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER',
        profilePhotoUrl: 'https://img.com/photo.jpg',
      );
      expect(p.hasProfilePhoto, isTrue);
    });

    test('false when URL is null', () {
      final p = UserProfile(
        id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER',
      );
      expect(p.hasProfilePhoto, isFalse);
    });

    test('false when URL is empty string', () {
      final p = UserProfile(
        id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER',
        profilePhotoUrl: '',
      );
      expect(p.hasProfilePhoto, isFalse);
    });
  });

  // ==================== UserProfile.initials ====================

  group('UserProfile.initials', () {
    test('returns two initials for two-word name', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'John Doe', role: 'MEMBER');
      expect(p.initials, 'JD');
    });

    test('returns one initial for single-word name', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'Alice', role: 'MEMBER');
      expect(p.initials, 'A');
    });

    test('returns U for empty name', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: '', role: 'MEMBER');
      expect(p.initials, 'U');
    });

    test('handles three-word name (takes first two)', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'Jean Marie Dupont', role: 'MEMBER');
      expect(p.initials, 'JM');
    });

    test('initials are uppercase', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'alice bob', role: 'MEMBER');
      expect(p.initials, 'AB');
    });

    test('handles single character name', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'x', role: 'MEMBER');
      expect(p.initials, 'X');
    });
  });

  // ==================== UserProfile.roleDisplay ====================

  group('UserProfile.roleDisplay', () {
    test('OWNER -> Proprietaire', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'T', role: 'OWNER');
      expect(p.roleDisplay, 'Proprietaire');
    });

    test('MEMBER -> Membre', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER');
      expect(p.roleDisplay, 'Membre');
    });

    test('GUEST -> Invite', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'T', role: 'GUEST');
      expect(p.roleDisplay, 'Invite');
    });

    test('unknown role returns the role itself', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'T', role: 'ADMIN');
      expect(p.roleDisplay, 'ADMIN');
    });
  });

  // ==================== UserProfile.joinDateFormatted ====================

  group('UserProfile.joinDateFormatted', () {
    test('returns formatted date', () {
      final p = UserProfile(
        id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER',
        createdAt: DateTime(2025, 3, 15),
      );
      expect(p.joinDateFormatted, '15 mars 2025');
    });

    test('returns Date inconnue when null', () {
      final p = UserProfile(id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER');
      expect(p.joinDateFormatted, 'Date inconnue');
    });

    test('handles January correctly', () {
      final p = UserProfile(
        id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(p.joinDateFormatted, '1 janvier 2026');
    });

    test('handles December correctly', () {
      final p = UserProfile(
        id: '1', email: 'a@b.com', displayName: 'T', role: 'MEMBER',
        createdAt: DateTime(2025, 12, 31),
      );
      expect(p.joinDateFormatted, '31 decembre 2025');
    });
  });

  // ==================== UserStats ====================

  group('UserStats.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'totalPlants': 10,
        'wateringsThisMonth': 25,
        'wateringStreak': 7,
        'healthyPlantsPercentage': 80,
        'oldestPlantName': 'Old Fern',
        'oldestPlantAcquiredAt': '2020-06-15T00:00:00Z',
      };
      final s = UserStats.fromJson(json);
      expect(s.totalPlants, 10);
      expect(s.wateringsThisMonth, 25);
      expect(s.wateringStreak, 7);
      expect(s.healthyPlantsPercentage, 80);
      expect(s.oldestPlantName, 'Old Fern');
      expect(s.oldestPlantAcquiredAt, isNotNull);
    });

    test('defaults numeric fields to reasonable values', () {
      final json = <String, dynamic>{};
      final s = UserStats.fromJson(json);
      expect(s.totalPlants, 0);
      expect(s.wateringsThisMonth, 0);
      expect(s.wateringStreak, 0);
      expect(s.healthyPlantsPercentage, 100);
      expect(s.oldestPlantName, isNull);
      expect(s.oldestPlantAcquiredAt, isNull);
    });
  });

  group('UserStats.oldestPlantAgeText', () {
    test('returns Aucune plante when no date', () {
      final s = UserStats(
        totalPlants: 0, wateringsThisMonth: 0,
        wateringStreak: 0, healthyPlantsPercentage: 100,
      );
      expect(s.oldestPlantAgeText, 'Aucune plante');
    });

    test('returns days for recent acquisition', () {
      final s = UserStats(
        totalPlants: 1, wateringsThisMonth: 0,
        wateringStreak: 0, healthyPlantsPercentage: 100,
        oldestPlantAcquiredAt: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(s.oldestPlantAgeText, contains('jour'));
    });

    test('returns months for older acquisition', () {
      final s = UserStats(
        totalPlants: 1, wateringsThisMonth: 0,
        wateringStreak: 0, healthyPlantsPercentage: 100,
        oldestPlantAcquiredAt: DateTime.now().subtract(const Duration(days: 90)),
      );
      expect(s.oldestPlantAgeText, contains('mois'));
    });

    test('returns years for very old acquisition', () {
      final s = UserStats(
        totalPlants: 1, wateringsThisMonth: 0,
        wateringStreak: 0, healthyPlantsPercentage: 100,
        oldestPlantAcquiredAt: DateTime.now().subtract(const Duration(days: 400)),
      );
      expect(s.oldestPlantAgeText, contains('an'));
    });

    test('handles zero days (acquired today)', () {
      final s = UserStats(
        totalPlants: 1, wateringsThisMonth: 0,
        wateringStreak: 0, healthyPlantsPercentage: 100,
        oldestPlantAcquiredAt: DateTime.now(),
      );
      expect(s.oldestPlantAgeText, contains('jour'));
    });
  });
}
