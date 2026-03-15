/// House member model
class HouseMember {
  final String id;
  final String displayName;
  final String email;
  final String? profilePhotoPath;
  final String role;
  final DateTime joinedAt;
  final bool isActive;

  HouseMember({
    required this.id,
    required this.displayName,
    required this.email,
    this.profilePhotoPath,
    required this.role,
    required this.joinedAt,
    required this.isActive,
  });

  factory HouseMember.fromJson(Map<String, dynamic> json) {
    return HouseMember(
      id: json['userId'] as String,
      displayName: json['displayName'] as String? ?? 'Utilisateur',
      email: json['email'] as String? ?? '',
      // Backend may return profilePhotoUrl or profilePhotoPath
      profilePhotoPath: (json['profilePhotoUrl'] ?? json['profilePhotoPath']) as String?,
      role: json['role'] as String? ?? 'MEMBER',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  /// Check if member is owner
  bool get isOwner => role == 'OWNER';

  /// Check if member is guest
  bool get isGuest => role == 'GUEST';

  /// Get role display name in French
  String get roleDisplayName {
    switch (role) {
      case 'OWNER':
        return 'Proprietaire';
      case 'GUEST':
        return 'Invite';
      default:
        return 'Membre';
    }
  }

  /// Get initials for avatar
  String get initials {
    if (displayName.isEmpty) return '?';
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.substring(0, 1).toUpperCase();
  }
}
