import 'package:dio/dio.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/models/user_profile.dart';
import 'package:planto/core/services/api_client.dart';

/// Service for user profile API operations.
/// Uses ApiClient with automatic token refresh.
class ProfileService {
  late final Dio _dio;
  ProfileService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get current user profile
  Future<UserProfile> getCurrentUser() async {
    try {
      final response = await _dio.get('/api/v1/auth/me');

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      } else {
        throw Exception('Failed to load user profile');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expiree');
      }
      throw Exception('Erreur reseau: ${e.message}');
    }
  }

  /// Get user statistics
  Future<UserStats> getUserStats() async {
    try {
      final response = await _dio.get('/api/v1/auth/me/stats');

      if (response.statusCode == 200) {
        return UserStats.fromJson(response.data);
      } else {
        throw Exception('Failed to load user stats');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expiree');
      }
      throw Exception('Erreur reseau: ${e.message}');
    }
  }

  /// Update user profile (display name)
  Future<UserProfile> updateProfile({String? displayName}) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null) data['displayName'] = displayName;

      final response = await _dio.put('/api/v1/auth/me', data: data);

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      } else {
        throw Exception('Failed to update profile');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.put(
        '/api/v1/auth/me/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Mot de passe actuel incorrect');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/api/v1/auth/me');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Upload profile photo (works on Web and Mobile)
  Future<UserProfile> uploadProfilePhotoBytes(List<int> bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/api/v1/auth/me/photo',
        data: formData,
      );

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      } else {
        throw Exception('Failed to upload photo');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] ?? 'Fichier invalide';
        throw Exception(message);
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Delete profile photo
  Future<UserProfile> deleteProfilePhoto() async {
    try {
      final response = await _dio.delete('/api/v1/auth/me/photo');

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      } else {
        throw Exception('Failed to delete photo');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Verify email with 6-digit code
  Future<UserProfile> verifyEmail(String code) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/verify-email',
        data: {'code': code},
      );

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      } else {
        throw Exception('Echec de la verification');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Code invalide ou expire');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Resend email verification code
  Future<void> resendVerification() async {
    try {
      await _dio.post('/api/v1/auth/resend-verification');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Get full URL for profile photo
  String? getProfilePhotoFullUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    return '${AppConstants.apiBaseUrl}$relativePath';
  }
}
