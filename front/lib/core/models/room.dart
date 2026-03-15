import 'package:planto/core/constants/app_constants.dart';

import 'plant.dart';

/// Room model with nested plants
class Room {
  final String id;
  final String name;
  final String type; // LIVING_ROOM, BEDROOM, BALCONY, etc.
  final int plantCount;
  final List<PlantSummary> plants;

  Room({
    required this.id,
    required this.name,
    required this.type,
    required this.plantCount,
    required this.plants,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final plantsJson = json['plants'] as List<dynamic>? ?? [];
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'OTHER',
      plantCount: json['plantCount'] as int? ?? 0,
      plants: plantsJson.map((p) => PlantSummary.fromJson(p)).toList(),
    );
  }

  /// Get room type display text
  String get typeDisplay {
    switch (type) {
      case 'LIVING_ROOM':
        return 'Salon';
      case 'BEDROOM':
        return 'Chambre';
      case 'BALCONY':
        return 'Balcon';
      case 'GARDEN':
        return 'Jardin';
      case 'KITCHEN':
        return 'Cuisine';
      case 'BATHROOM':
        return 'Salle de bain';
      case 'OFFICE':
        return 'Bureau';
      default:
        return 'Autre';
    }
  }

  /// Get room icon
  String get icon {
    switch (type) {
      case 'LIVING_ROOM':
        return '🛋️';
      case 'BEDROOM':
        return '🛏️';
      case 'BALCONY':
        return '🌿';
      case 'GARDEN':
        return '🌳';
      case 'KITCHEN':
        return '🍳';
      case 'BATHROOM':
        return '🚿';
      case 'OFFICE':
        return '💼';
      default:
        return '🏠';
    }
  }
}

/// Simplified plant for room listing
class PlantSummary {
  final String id;
  final String nickname;
  final String? photoUrl;
  final String? speciesCommonName;
  final bool needsWatering;
  final DateTime? nextWateringDate;
  final bool isSick;
  final bool isWilted;
  final bool needsRepotting;

  PlantSummary({
    required this.id,
    required this.nickname,
    this.photoUrl,
    this.speciesCommonName,
    required this.needsWatering,
    this.nextWateringDate,
    this.isSick = false,
    this.isWilted = false,
    this.needsRepotting = false,
  });

  factory PlantSummary.fromJson(Map<String, dynamic> json) {
    final status = json['healthStatus'] as String? ?? 'GOOD';

    // Build full photo URL from relative path
    String? photoUrl;
    final rawPhotoUrl = json['photoUrl'] as String?;
    if (rawPhotoUrl != null && rawPhotoUrl.isNotEmpty) {
      if (rawPhotoUrl.startsWith('http://') || rawPhotoUrl.startsWith('https://')) {
        photoUrl = rawPhotoUrl;
      } else {
        // Prepend base URL for relative paths
        photoUrl = '${AppConstants.apiBaseUrl}$rawPhotoUrl';
      }
    }

    return PlantSummary(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? 'Sans nom',
      photoUrl: photoUrl,
      speciesCommonName: json['speciesCommonName'] as String?,
      needsWatering: json['needsWatering'] as bool? ?? false,
      nextWateringDate: json['nextWateringDate'] != null
          ? DateTime.tryParse(json['nextWateringDate'] as String)
          : null,
      // Attempt to read direct booleans, fallback to status string mapping
      isSick: json['isSick'] as bool? ?? (status == 'SICK'),
      isWilted: json['isWilted'] as bool? ?? (status == 'WILTED'),
      needsRepotting: json['needsRepotting'] as bool? ?? false,
    );
  }

  /// Calculate days until next watering
  int get daysUntilWatering {
    if (nextWateringDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final wateringDay = DateTime(
      nextWateringDate!.year,
      nextWateringDate!.month,
      nextWateringDate!.day,
    );
    return wateringDay.difference(today).inDays;
  }

  /// Check if plant is urgent (needs watering today or overdue)
  bool get isUrgent => daysUntilWatering <= 0;
}
