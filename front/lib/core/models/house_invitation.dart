/// Model for a house join request / invitation.
class HouseInvitation {
  final String id;
  final String houseId;
  final String houseName;
  final String requesterId;
  final String requesterName;
  final String requesterEmail;
  final String status; // PENDING, ACCEPTED, DECLINED
  final String? respondedById;
  final String? respondedByName;
  final DateTime createdAt;
  final DateTime? respondedAt;

  HouseInvitation({
    required this.id,
    required this.houseId,
    required this.houseName,
    required this.requesterId,
    required this.requesterName,
    required this.requesterEmail,
    required this.status,
    this.respondedById,
    this.respondedByName,
    required this.createdAt,
    this.respondedAt,
  });

  factory HouseInvitation.fromJson(Map<String, dynamic> json) {
    return HouseInvitation(
      id: json['id'],
      houseId: json['houseId'],
      houseName: json['houseName'] ?? '',
      requesterId: json['requesterId'],
      requesterName: json['requesterName'] ?? '',
      requesterEmail: json['requesterEmail'] ?? '',
      status: json['status'] ?? 'PENDING',
      respondedById: json['respondedById'],
      respondedByName: json['respondedByName'],
      createdAt: DateTime.parse(json['createdAt']),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isDeclined => status == 'DECLINED';
}
