/// User profile model
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String role;
  final DateTime? createdAt;
  final String? profilePhotoUrl;
  final bool emailVerified;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.createdAt,
    this.profilePhotoUrl,
    this.emailVerified = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? 'Utilisateur',
      role: json['role'] as String? ?? 'MEMBER',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }

  /// Check if user has a profile photo
  bool get hasProfilePhoto => profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty;

  /// Get initials for avatar
  String get initials {
    if (displayName.isEmpty) return 'U';
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }

  /// Get role display text
  String get roleDisplay {
    switch (role) {
      case 'OWNER':
        return 'Proprietaire';
      case 'GUEST':
        return 'Invite';
      case 'MEMBER':
        return 'Membre';
      default:
        return role;
    }
  }

  /// Get formatted join date
  String get joinDateFormatted {
    if (createdAt == null) return 'Date inconnue';
    final months = [
      'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre'
    ];
    return '${createdAt!.day} ${months[createdAt!.month - 1]} ${createdAt!.year}';
  }
}

/// User statistics model
class UserStats {
  final int totalPlants;
  final int wateringsThisMonth;
  final int wateringStreak;
  final int healthyPlantsPercentage;
  final String? oldestPlantName;
  final DateTime? oldestPlantAcquiredAt;

  UserStats({
    required this.totalPlants,
    required this.wateringsThisMonth,
    required this.wateringStreak,
    required this.healthyPlantsPercentage,
    this.oldestPlantName,
    this.oldestPlantAcquiredAt,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalPlants: json['totalPlants'] as int? ?? 0,
      wateringsThisMonth: json['wateringsThisMonth'] as int? ?? 0,
      wateringStreak: json['wateringStreak'] as int? ?? 0,
      healthyPlantsPercentage: json['healthyPlantsPercentage'] as int? ?? 100,
      oldestPlantName: json['oldestPlantName'] as String?,
      oldestPlantAcquiredAt: json['oldestPlantAcquiredAt'] != null
          ? DateTime.tryParse(json['oldestPlantAcquiredAt'] as String)
          : null,
    );
  }

  /// Get oldest plant age text
  String get oldestPlantAgeText {
    if (oldestPlantAcquiredAt == null) return 'Aucune plante';
    final now = DateTime.now();
    final diff = now.difference(oldestPlantAcquiredAt!);
    final years = diff.inDays ~/ 365;
    final months = (diff.inDays % 365) ~/ 30;
    final days = diff.inDays % 30;

    if (years > 0) {
      return '$years an${years > 1 ? 's' : ''} ${months > 0 ? 'et $months mois' : ''}';
    } else if (months > 0) {
      return '$months mois${days > 0 ? ' et $days jour${days > 1 ? 's' : ''}' : ''}';
    } else {
      return '$days jour${days > 1 ? 's' : ''}';
    }
  }
}
