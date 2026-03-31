/// Vacation delegation model
class VacationDelegation {
  final String id;
  final String houseId;
  final String delegatorId;
  final String delegatorName;
  final String delegateId;
  final String delegateName;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? message;
  final DateTime createdAt;

  VacationDelegation({
    required this.id,
    required this.houseId,
    required this.delegatorId,
    required this.delegatorName,
    required this.delegateId,
    required this.delegateName,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.message,
    required this.createdAt,
  });

  factory VacationDelegation.fromJson(Map<String, dynamic> json) {
    return VacationDelegation(
      id: json['id'] as String,
      houseId: json['houseId'] as String? ?? '',
      delegatorId: json['delegatorId'] as String? ?? '',
      delegatorName: json['delegatorName'] as String? ?? 'Utilisateur',
      delegateId: json['delegateId'] as String? ?? '',
      delegateName: json['delegateName'] as String? ?? 'Utilisateur',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: json['status'] as String? ?? 'ACTIVE',
      message: json['message'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isCancelled => status == 'CANCELLED';
  bool get isExpired => status == 'EXPIRED';

  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays;
  }
}
