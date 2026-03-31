import 'package:dio/dio.dart';
import 'package:planto/core/services/api_client.dart';
import 'package:planto/core/utils/api_error_formatter.dart';

/// Model for an in-app notification from the API.
class AppNotification {
  final String id;
  final String type;
  final String message;
  final bool read;
  final String? plantId;
  final String? plantNickname;
  final String? invitationId;
  final String? houseId;
  final String? houseName;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.read,
    this.plantId,
    this.plantNickname,
    this.invitationId,
    this.houseId,
    this.houseName,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      read: json['read'] ?? false,
      plantId: json['plantId'],
      plantNickname: json['plantNickname'],
      invitationId: json['invitationId'],
      houseId: json['houseId'],
      houseName: json['houseName'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  bool get isHouseInvitation => type == 'HOUSE_INVITATION' && invitationId != null;
}

/// Service for in-app notifications from the backend API.
class NotificationApiService {
  late final Dio _dio;

  NotificationApiService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all notifications
  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    try {
      final response = await _dio.get(
        '/api/v1/notifications',
        queryParameters: {'unreadOnly': unreadOnly},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AppNotification.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de charger les notifications'),
      );
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('/api/v1/notifications/unread-count');

      if (response.statusCode == 200) {
        return response.data['unreadCount'] ?? 0;
      }
      return 0;
    } on DioException {
      return 0;
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dio.put('/api/v1/notifications/$notificationId/read');
    } on DioException {
      // Ignore errors
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _dio.put('/api/v1/notifications/read-all');
    } on DioException {
      // Ignore errors
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _dio.delete('/api/v1/notifications/$notificationId');
    } on DioException {
      // Ignore errors
    }
  }
}
