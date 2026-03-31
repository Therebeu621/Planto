/// Care log entry model - tracks plant care history
class CareLog {
  final String id;
  final String action;
  final String? notes;
  final DateTime performedAt;
  final String? performedByName;

  CareLog({
    required this.id,
    required this.action,
    this.notes,
    required this.performedAt,
    this.performedByName,
  });

  factory CareLog.fromJson(Map<String, dynamic> json) {
    return CareLog(
      id: json['id'] as String,
      action: json['action'] as String,
      notes: json['notes'] as String?,
      performedAt: DateTime.parse(json['performedAt'] as String),
      performedByName: json['performedByName'] as String?,
    );
  }

  /// Get action display text in French
  String get actionDisplay {
    switch (action) {
      case 'WATERING':
        return 'Arrosage';
      case 'FERTILIZING':
        return 'Fertilisation';
      case 'REPOTTING':
        return 'Rempotage';
      case 'PRUNING':
        return 'Taille';
      case 'TREATMENT':
        return 'Traitement';
      case 'NOTE':
        return 'Memo';
      default:
        return action;
    }
  }

  /// Get action icon
  String get actionIcon {
    switch (action) {
      case 'WATERING':
        return '💧';
      case 'FERTILIZING':
        return '🌱';
      case 'REPOTTING':
        return '🪴';
      case 'PRUNING':
        return '✂️';
      case 'TREATMENT':
        return '💊';
      case 'NOTE':
        return '📝';
      default:
        return '🌿';
    }
  }

  /// Format relative time
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(performedAt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'Il y a ${diff.inMinutes} min';
      }
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'Il y a $weeks sem.';
    } else {
      final months = (diff.inDays / 30).floor();
      return 'Il y a $months mois';
    }
  }
}
