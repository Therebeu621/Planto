import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/services/gamification_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late GamificationService service;

  final badgeJson = {
    'code': 'FIRST_PLANT',
    'name': 'First Plant',
    'description': 'Added your first plant',
    'category': 'PLANTS',
    'iconUrl': '/icons/first_plant.png',
    'unlocked': true,
    'unlockedAt': '2026-01-15T10:00:00Z',
  };

  final lockedBadgeJson = {
    'code': 'MASTER_GARDENER',
    'name': 'Master Gardener',
    'description': 'Have 50 plants',
    'category': 'PLANTS',
    'iconUrl': '/icons/master.png',
    'unlocked': false,
  };

  final profileJson = {
    'xp': 250,
    'level': 3,
    'levelName': 'Pousse',
    'xpForNextLevel': 100,
    'xpProgressInLevel': 50,
    'wateringStreak': 5,
    'bestWateringStreak': 10,
    'totalWaterings': 42,
    'totalCareActions': 60,
    'totalPlantsAdded': 8,
    'badges': [badgeJson, lockedBadgeJson],
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = GamificationService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getProfile', () {
    test('success returns gamification profile', () async {
      mockInterceptor.addMockResponse('/api/v1/gamification/profile',
          data: profileJson);
      final result = await service.getProfile();
      expect(result, isA<GamificationProfile>());
      expect(result.xp, 250);
      expect(result.level, 3);
      expect(result.levelName, 'Pousse');
      expect(result.xpForNextLevel, 100);
      expect(result.xpProgressInLevel, 50);
      expect(result.wateringStreak, 5);
      expect(result.bestWateringStreak, 10);
      expect(result.totalWaterings, 42);
      expect(result.totalCareActions, 60);
      expect(result.totalPlantsAdded, 8);
      expect(result.badges.length, 2);
    });
  });

  group('getLeaderboard', () {
    test('success returns list of profiles', () async {
      mockInterceptor.addMockResponse('/api/v1/gamification/leaderboard/h1',
          data: [profileJson]);
      final result = await service.getLeaderboard('h1');
      expect(result, isA<List<GamificationProfile>>());
      expect(result.length, 1);
      expect(result.first.xp, 250);
    });
  });

  group('GamificationProfile', () {
    test('fromJson parses correctly', () {
      final profile = GamificationProfile.fromJson(profileJson);
      expect(profile.xp, 250);
      expect(profile.level, 3);
      expect(profile.badges.length, 2);
    });

    test('fromJson with missing fields uses defaults', () {
      final profile = GamificationProfile.fromJson({});
      expect(profile.xp, 0);
      expect(profile.level, 1);
      expect(profile.levelName, 'Graine');
      expect(profile.xpForNextLevel, 100);
      expect(profile.xpProgressInLevel, 0);
      expect(profile.wateringStreak, 0);
      expect(profile.bestWateringStreak, 0);
      expect(profile.totalWaterings, 0);
      expect(profile.totalCareActions, 0);
      expect(profile.totalPlantsAdded, 0);
      expect(profile.badges, isEmpty);
    });

    test('xpProgress calculates correctly', () {
      final profile = GamificationProfile.fromJson(profileJson);
      expect(profile.xpProgress, 0.5); // 50/100
    });

    test('xpProgress returns 0 when xpForNextLevel is 0', () {
      final profile = GamificationProfile.fromJson({
        ...profileJson,
        'xpForNextLevel': 0,
      });
      expect(profile.xpProgress, 0);
    });

    test('unlockedBadges returns only unlocked badges', () {
      final profile = GamificationProfile.fromJson(profileJson);
      final unlocked = profile.unlockedBadges;
      expect(unlocked.length, 1);
      expect(unlocked.first.code, 'FIRST_PLANT');
      expect(unlocked.first.unlocked, true);
    });
  });

  group('BadgeInfo', () {
    test('fromJson parses correctly', () {
      final badge = BadgeInfo.fromJson(badgeJson);
      expect(badge.code, 'FIRST_PLANT');
      expect(badge.name, 'First Plant');
      expect(badge.description, 'Added your first plant');
      expect(badge.category, 'PLANTS');
      expect(badge.iconUrl, '/icons/first_plant.png');
      expect(badge.unlocked, true);
      expect(badge.unlockedAt, '2026-01-15T10:00:00Z');
    });

    test('fromJson with missing fields uses defaults', () {
      final badge = BadgeInfo.fromJson({});
      expect(badge.code, '');
      expect(badge.name, '');
      expect(badge.description, '');
      expect(badge.category, '');
      expect(badge.iconUrl, '');
      expect(badge.unlocked, false);
      expect(badge.unlockedAt, isNull);
    });
  });
}
