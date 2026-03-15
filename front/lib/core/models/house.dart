/// House model
class House {
  final String id;
  final String name;
  final String inviteCode;
  final int memberCount;
  final int roomCount;
  final bool isActive;
  final String? role;

  House({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberCount,
    required this.roomCount,
    required this.isActive,
    this.role,
  });

  factory House.fromJson(Map<String, dynamic> json) {
    return House(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sans nom',
      inviteCode: json['inviteCode'] as String? ?? '',
      memberCount: json['memberCount'] as int? ?? 0,
      roomCount: json['roomCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      role: json['role'] as String?,
    );
  }

  /// Check if user is owner
  bool get isOwner => role == 'OWNER';
}
