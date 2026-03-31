import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/models/care_log.dart';

/// Plant model
class Plant {
  final String id;
  final String nickname;
  final String? photoUrl;
  final String? speciesCommonName;
  final bool needsWatering;
  final bool isSick;
  final bool isWilted;
  final bool needsRepotting;
  final String? exposure; // SUN, SHADE, PARTIAL_SHADE
  final int? wateringIntervalDays;
  final DateTime? lastWatered;
  final DateTime? nextWateringDate;
  final String? notes;
  final double? potDiameterCm;
  final String? roomId;
  final String? roomName;
  final DateTime? acquiredAt;
  final DateTime? createdAt;

  // Detailed species info (from PlantDetailDTO)
  final SpeciesInfo? species;

  // Room info (from PlantDetailDTO)
  final RoomInfo? room;

  // Recent care logs (from PlantDetailDTO)
  final List<CareLog> recentCareLogs;

  // Whether the current user can manage (write) this plant
  final bool canManage;

  Plant({
    required this.id,
    required this.nickname,
    this.photoUrl,
    this.speciesCommonName,
    required this.needsWatering,
    required this.isSick,
    required this.isWilted,
    required this.needsRepotting,
    this.exposure,
    this.wateringIntervalDays,
    this.lastWatered,
    this.nextWateringDate,
    this.notes,
    this.potDiameterCm,
    this.roomId,
    this.roomName,
    this.acquiredAt,
    this.createdAt,
    this.species,
    this.room,
    this.recentCareLogs = const [],
    this.canManage = true,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    // Parse room info
    RoomInfo? roomInfo;
    if (json['room'] != null) {
      roomInfo = RoomInfo.fromJson(json['room'] as Map<String, dynamic>);
    }

    // Parse species info
    SpeciesInfo? speciesInfo;
    if (json['species'] != null) {
      speciesInfo = SpeciesInfo.fromJson(json['species'] as Map<String, dynamic>);
    }

    // Parse care logs
    List<CareLog> careLogs = [];
    if (json['recentCareLogs'] != null) {
      careLogs = (json['recentCareLogs'] as List)
          .map((e) => CareLog.fromJson(e as Map<String, dynamic>))
          .toList();
    }

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

    return Plant(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? 'Sans nom',
      photoUrl: photoUrl,
      speciesCommonName: json['speciesCommonName'] as String? ??
          speciesInfo?.commonName,
      needsWatering: json['needsWatering'] as bool? ?? false,
      isSick: json['isSick'] as bool? ?? false,
      isWilted: json['isWilted'] as bool? ?? false,
      needsRepotting: json['needsRepotting'] as bool? ?? false,
      exposure: json['exposure'] as String?,
      wateringIntervalDays: json['wateringIntervalDays'] as int?,
      lastWatered: json['lastWatered'] != null
          ? DateTime.tryParse(json['lastWatered'] as String)
          : null,
      nextWateringDate: json['nextWateringDate'] != null
          ? DateTime.tryParse(json['nextWateringDate'] as String)
          : null,
      notes: json['notes'] as String?,
      potDiameterCm: json['potDiameterCm'] != null
          ? (json['potDiameterCm'] as num).toDouble()
          : null,
      roomId: json['roomId'] as String? ?? roomInfo?.id,
      roomName: json['roomName'] as String? ?? roomInfo?.name,
      acquiredAt: json['acquiredAt'] != null
          ? DateTime.tryParse(json['acquiredAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      species: speciesInfo,
      room: roomInfo,
      recentCareLogs: careLogs,
      canManage: json['canManage'] as bool? ?? true,
    );
  }

  /// Get days until next watering
  int? get daysUntilWatering {
    if (nextWateringDate == null) return null;
    return nextWateringDate!.difference(DateTime.now()).inDays;
  }

  /// Get exposure display text
  String get exposureDisplay {
    switch (exposure) {
      case 'SUN':
        return 'Plein soleil';
      case 'SHADE':
        return 'Ombre';
      case 'PARTIAL_SHADE':
        return 'Mi-ombre';
      default:
        return 'Non defini';
    }
  }

  /// Get health status
  String get healthStatus {
    if (isSick) return 'Malade';
    if (isWilted) return 'Fanee';
    if (needsRepotting) return 'A rempoter';
    if (needsWatering) return 'A arroser';
    return 'En forme';
  }

  /// Get pot size display text
  String get potSizeDisplay {
    if (potDiameterCm == null) return 'Non defini';
    final d = potDiameterCm!;
    return '${d.truncateToDouble() == d ? d.toInt().toString() : d.toStringAsFixed(1)} cm';
  }

  /// Check if plant has any health issues
  bool get hasHealthIssues => isSick || isWilted || needsRepotting;

  /// Get watering status text
  String get wateringStatusText {
    final days = daysUntilWatering;
    if (days == null) return 'Non programme';
    if (days < 0) return 'En retard de ${-days} jour${-days > 1 ? 's' : ''}';
    if (days == 0) return 'A arroser aujourd\'hui';
    if (days == 1) return 'A arroser demain';
    return 'Dans $days jours';
  }
}

/// Species information from backend
class SpeciesInfo {
  final String? id;
  final int? trefleId;
  final String? commonName;
  final String? scientificName;
  final String? family;
  final String? genus;
  final String? imageUrl;

  SpeciesInfo({
    this.id,
    this.trefleId,
    this.commonName,
    this.scientificName,
    this.family,
    this.genus,
    this.imageUrl,
  });

  factory SpeciesInfo.fromJson(Map<String, dynamic> json) {
    return SpeciesInfo(
      id: json['id'] as String?,
      trefleId: json['trefleId'] as int?,
      commonName: json['commonName'] as String?,
      scientificName: json['scientificName'] as String?,
      family: json['family'] as String?,
      genus: json['genus'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

/// Room information from backend
class RoomInfo {
  final String id;
  final String name;
  final String? type;

  RoomInfo({
    required this.id,
    required this.name,
    this.type,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
    );
  }

  /// Get room icon based on type
  String get icon {
    switch (type) {
      case 'LIVING_ROOM':
        return '🛋️';
      case 'BEDROOM':
        return '🛏️';
      case 'BALCONY':
        return '🌿';
      case 'GARDEN':
        return '🏡';
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
