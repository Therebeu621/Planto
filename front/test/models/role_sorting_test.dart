import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/house_member.dart';

/// Tests for role sorting logic used in house_members_page.dart
void main() {
  // Replicates the sorting logic from HouseMembersPage._loadData()
  int roleOrder(String role) {
    switch (role) {
      case 'OWNER':
        return 0;
      case 'MEMBER':
        return 1;
      case 'GUEST':
        return 2;
      default:
        return 3;
    }
  }

  void sortMembers(List<HouseMember> members) {
    members.sort((a, b) {
      final roleCompare = roleOrder(a.role).compareTo(roleOrder(b.role));
      if (roleCompare != 0) return roleCompare;
      return a.displayName.compareTo(b.displayName);
    });
  }

  HouseMember _make(String name, String role) {
    return HouseMember(
      id: name.toLowerCase().replaceAll(' ', '-'),
      displayName: name,
      email: '${name.toLowerCase().replaceAll(' ', '')}@test.com',
      role: role,
      joinedAt: DateTime.now(),
      isActive: true,
    );
  }

  // ==================== SORTING ORDER ====================

  group('Role sorting order (OWNER > MEMBER > GUEST)', () {
    test('OWNER comes before MEMBER', () {
      final members = [_make('Bob', 'MEMBER'), _make('Alice', 'OWNER')];
      sortMembers(members);
      expect(members[0].displayName, 'Alice');
      expect(members[0].role, 'OWNER');
      expect(members[1].displayName, 'Bob');
      expect(members[1].role, 'MEMBER');
    });

    test('MEMBER comes before GUEST', () {
      final members = [_make('Charlie', 'GUEST'), _make('Bob', 'MEMBER')];
      sortMembers(members);
      expect(members[0].role, 'MEMBER');
      expect(members[1].role, 'GUEST');
    });

    test('OWNER comes before GUEST', () {
      final members = [_make('Charlie', 'GUEST'), _make('Alice', 'OWNER')];
      sortMembers(members);
      expect(members[0].role, 'OWNER');
      expect(members[1].role, 'GUEST');
    });

    test('full hierarchy: OWNER > MEMBER > GUEST', () {
      final members = [
        _make('Charlie', 'GUEST'),
        _make('Bob', 'MEMBER'),
        _make('Alice', 'OWNER'),
      ];
      sortMembers(members);
      expect(members.map((m) => m.role).toList(), ['OWNER', 'MEMBER', 'GUEST']);
    });

    test('unknown role comes after GUEST', () {
      final members = [
        _make('Unknown', 'ADMIN'),
        _make('Guest', 'GUEST'),
        _make('Owner', 'OWNER'),
      ];
      sortMembers(members);
      expect(members.map((m) => m.role).toList(), ['OWNER', 'GUEST', 'ADMIN']);
    });
  });

  // ==================== ALPHABETICAL WITHIN ROLE ====================

  group('Alphabetical sort within same role', () {
    test('owners sorted alphabetically', () {
      final members = [
        _make('Zoe', 'OWNER'),
        _make('Alice', 'OWNER'),
        _make('Mike', 'OWNER'),
      ];
      sortMembers(members);
      expect(members.map((m) => m.displayName).toList(), ['Alice', 'Mike', 'Zoe']);
    });

    test('members sorted alphabetically', () {
      final members = [
        _make('Zoe', 'MEMBER'),
        _make('Alice', 'MEMBER'),
      ];
      sortMembers(members);
      expect(members.map((m) => m.displayName).toList(), ['Alice', 'Zoe']);
    });

    test('guests sorted alphabetically', () {
      final members = [
        _make('Zoe', 'GUEST'),
        _make('Alice', 'GUEST'),
        _make('Bob', 'GUEST'),
      ];
      sortMembers(members);
      expect(members.map((m) => m.displayName).toList(), ['Alice', 'Bob', 'Zoe']);
    });
  });

  // ==================== COMPLEX SCENARIOS ====================

  group('Complex sorting scenarios', () {
    test('mixed roles with multiple members per role', () {
      final members = [
        _make('Zoe Guest', 'GUEST'),
        _make('Alice Member', 'MEMBER'),
        _make('Bob Owner', 'OWNER'),
        _make('Alice Guest', 'GUEST'),
        _make('Charlie Member', 'MEMBER'),
        _make('Alice Owner', 'OWNER'),
      ];
      sortMembers(members);
      expect(members.map((m) => '${m.role}:${m.displayName}').toList(), [
        'OWNER:Alice Owner',
        'OWNER:Bob Owner',
        'MEMBER:Alice Member',
        'MEMBER:Charlie Member',
        'GUEST:Alice Guest',
        'GUEST:Zoe Guest',
      ]);
    });

    test('single member list stays unchanged', () {
      final members = [_make('Solo', 'GUEST')];
      sortMembers(members);
      expect(members.length, 1);
      expect(members[0].displayName, 'Solo');
    });

    test('empty list does not throw', () {
      final members = <HouseMember>[];
      sortMembers(members);
      expect(members, isEmpty);
    });

    test('all same role sorted alphabetically', () {
      final members = [
        _make('Charlie', 'GUEST'),
        _make('Alice', 'GUEST'),
        _make('Bob', 'GUEST'),
      ];
      sortMembers(members);
      expect(members.map((m) => m.displayName).toList(), ['Alice', 'Bob', 'Charlie']);
    });
  });

  // ==================== PERMISSION LOGIC (canManage) ====================

  group('canManage permission logic', () {
    // Replicates: canManage = house.isOwner && !isCurrentUser
    bool canManage({required String houseRole, required String memberId, required String currentUserId}) {
      final isOwner = houseRole == 'OWNER';
      final isCurrentUser = memberId == currentUserId;
      return isOwner && !isCurrentUser;
    }

    test('owner can manage other members', () {
      expect(canManage(houseRole: 'OWNER', memberId: 'user2', currentUserId: 'user1'), isTrue);
    });

    test('owner cannot manage themselves', () {
      expect(canManage(houseRole: 'OWNER', memberId: 'user1', currentUserId: 'user1'), isFalse);
    });

    test('member cannot manage anyone', () {
      expect(canManage(houseRole: 'MEMBER', memberId: 'user2', currentUserId: 'user1'), isFalse);
    });

    test('guest cannot manage anyone', () {
      expect(canManage(houseRole: 'GUEST', memberId: 'user2', currentUserId: 'user1'), isFalse);
    });

    test('member cannot manage themselves', () {
      expect(canManage(houseRole: 'MEMBER', memberId: 'user1', currentUserId: 'user1'), isFalse);
    });

    test('guest cannot manage themselves', () {
      expect(canManage(houseRole: 'GUEST', memberId: 'user1', currentUserId: 'user1'), isFalse);
    });

    test('owner can manage a guest', () {
      expect(canManage(houseRole: 'OWNER', memberId: 'guest-user', currentUserId: 'owner-user'), isTrue);
    });

    test('owner can manage another owner (not self)', () {
      expect(canManage(houseRole: 'OWNER', memberId: 'owner2', currentUserId: 'owner1'), isTrue);
    });
  });

  // ==================== ROLE ORDER FUNCTION EDGE CASES ====================

  group('roleOrder function edge cases', () {
    test('OWNER has lowest order (highest priority)', () {
      expect(roleOrder('OWNER'), 0);
    });

    test('MEMBER is second', () {
      expect(roleOrder('MEMBER'), 1);
    });

    test('GUEST is third', () {
      expect(roleOrder('GUEST'), 2);
    });

    test('unknown role gets lowest priority', () {
      expect(roleOrder('ADMIN'), 3);
      expect(roleOrder('SUPERUSER'), 3);
      expect(roleOrder(''), 3);
    });

    test('role order is case-sensitive', () {
      expect(roleOrder('owner'), 3); // lowercase = unknown
      expect(roleOrder('guest'), 3);
      expect(roleOrder('member'), 3);
    });

    test('OWNER < MEMBER < GUEST < unknown (numerically)', () {
      expect(roleOrder('OWNER') < roleOrder('MEMBER'), isTrue);
      expect(roleOrder('MEMBER') < roleOrder('GUEST'), isTrue);
      expect(roleOrder('GUEST') < roleOrder('SOMETHING'), isTrue);
    });
  });
}
