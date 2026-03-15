import 'package:dio/dio.dart';
import 'package:planto/core/services/api_client.dart';

/// Service for gamification API calls
class GamificationService {
  late final Dio _dio;
  GamificationService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get current user's gamification profile
  Future<GamificationProfile> getProfile() async {
    final response = await _dio.get('/api/v1/gamification/profile');
    return GamificationProfile.fromJson(response.data);
  }

  /// Get leaderboard for a house
  Future<List<GamificationProfile>> getLeaderboard(String houseId) async {
    final response = await _dio.get('/api/v1/gamification/leaderboard/$houseId');
    return (response.data as List)
        .map((e) => GamificationProfile.fromJson(e))
        .toList();
  }
}

/// Gamification profile model
class GamificationProfile {
  final int xp;
  final int level;
  final String levelName;
  final int xpForNextLevel;
  final int xpProgressInLevel;
  final int wateringStreak;
  final int bestWateringStreak;
  final int totalWaterings;
  final int totalCareActions;
  final int totalPlantsAdded;
  final List<BadgeInfo> badges;

  GamificationProfile({
    required this.xp,
    required this.level,
    required this.levelName,
    required this.xpForNextLevel,
    required this.xpProgressInLevel,
    required this.wateringStreak,
    required this.bestWateringStreak,
    required this.totalWaterings,
    required this.totalCareActions,
    required this.totalPlantsAdded,
    required this.badges,
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> json) {
    return GamificationProfile(
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
      levelName: json['levelName'] ?? 'Graine',
      xpForNextLevel: json['xpForNextLevel'] ?? 100,
      xpProgressInLevel: json['xpProgressInLevel'] ?? 0,
      wateringStreak: json['wateringStreak'] ?? 0,
      bestWateringStreak: json['bestWateringStreak'] ?? 0,
      totalWaterings: json['totalWaterings'] ?? 0,
      totalCareActions: json['totalCareActions'] ?? 0,
      totalPlantsAdded: json['totalPlantsAdded'] ?? 0,
      badges: (json['badges'] as List?)
              ?.map((e) => BadgeInfo.fromJson(e))
              .toList() ??
          [],
    );
  }

  double get xpProgress =>
      xpForNextLevel > 0 ? xpProgressInLevel / xpForNextLevel : 0;

  List<BadgeInfo> get unlockedBadges => badges.where((b) => b.unlocked).toList();
}

/// Badge model
class BadgeInfo {
  final String code;
  final String name;
  final String description;
  final String category;
  final String iconUrl;
  final bool unlocked;
  final String? unlockedAt;

  BadgeInfo({
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.iconUrl,
    required this.unlocked,
    this.unlockedAt,
  });

  factory BadgeInfo.fromJson(Map<String, dynamic> json) {
    return BadgeInfo(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      unlocked: json['unlocked'] ?? false,
      unlockedAt: json['unlockedAt'],
    );
  }
}
