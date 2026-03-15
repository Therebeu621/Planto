import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/services/api_client.dart';
import 'package:planto/core/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service for login/logout operations.
/// Uses ApiClient for token refresh support.
class AuthService {
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userEmailKey = 'user_email';

  // Auth-specific Dio (no interceptor, to avoid refresh loops on login/register)
  late final Dio _dio;

  // Google Sign-In instance
  late final GoogleSignIn _googleSignIn;

  AuthService({Dio? dio}) {
    _dio = dio ?? Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      headers: {'Content-Type': 'application/json'},
    ));
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      // serverClientId is not supported on Web platform
      serverClientId: kIsWeb
          ? null
          : '767283060164-d7k6anlmagdgf67gq0mi35r2e6ga8e5v.apps.googleusercontent.com',
    );
  }

  /// Save tokens from auth response
  Future<void> _saveAuthTokens(Map<String, dynamic> data, String email) async {
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String? ?? '';

    await ApiClient.saveTokens(accessToken, refreshToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }

  /// Login with email and password
  /// Returns the user email on success, throws on failure
  Future<String> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        await _saveAuthTokens(response.data, email);
        // Register FCM token with backend (not on web)
        if (!kIsWeb) {
          try { await FcmService().registerToken(); } catch (_) {}
        }
        return email;
      } else {
        throw Exception('Login failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Email ou mot de passe incorrect');
      }
      throw Exception('Erreur de connexion: ${e.message}');
    }
  }

  /// Register a new user
  /// Returns the user email on success, throws on failure
  Future<String> register(String email, String password, String displayName) async {
    try {
      final response = await _dio.post('/api/v1/auth/register', data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      });

      if (response.statusCode == 201) {
        await _saveAuthTokens(response.data, email);
        // Register FCM token with backend (not on web)
        if (!kIsWeb) {
          try { await FcmService().registerToken(); } catch (_) {}
        }
        return email;
      } else {
        throw Exception('Registration failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('Cet email est déjà utilisé');
      }
      throw Exception('Erreur lors de l\'inscription: ${e.message}');
    }
  }

  /// Login with Google
  /// Returns the user email on success, throws on failure
  Future<String> loginWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Connexion Google annulée');
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Impossible de récupérer le token Google');
      }

      // Send token to backend for verification
      final response = await _dio.post('/api/v1/auth/google', data: {
        'idToken': idToken,
      });

      if (response.statusCode == 200) {
        final email = googleUser.email;
        await _saveAuthTokens(response.data, email);
        // Register FCM token with backend (not on web)
        if (!kIsWeb) {
          try { await FcmService().registerToken(); } catch (_) {}
        }
        return email;
      } else {
        throw Exception('Échec de la connexion Google');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Compte Google non autorisé');
      }
      throw Exception('Erreur de connexion Google: ${e.message}');
    } catch (e) {
      if (e.toString().contains('annulée')) {
        rethrow;
      }
      throw Exception('Erreur Google Sign-In: $e');
    }
  }

  /// Request password reset - sends a code to the email
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('/api/v1/auth/forgot-password', data: {
        'email': email,
      });
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Reset password with the code received by email
  Future<void> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await _dio.post('/api/v1/auth/reset-password', data: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });

      if (response.statusCode != 200) {
        throw Exception('Echec de la reinitialisation');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Code invalide ou expire');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Get saved token
  Future<String?> getToken() async {
    return ApiClient.getAccessToken();
  }

  /// Get saved user email
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Get user ID from JWT token (sub claim)
  Future<String?> getUserId() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      // JWT has 3 parts: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode payload (middle part)
      final payload = parts[1];
      // Add padding if needed for base64
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> data = jsonDecode(decoded);

      // 'sub' is the standard JWT claim for subject (user ID)
      return data['sub'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout - clear saved credentials
  Future<void> logout() async {
    // Unregister FCM token from backend (not on web)
    if (!kIsWeb) {
      try {
        await FcmService().unregisterToken();
      } catch (_) {
        // Ignore errors during unregister
      }
    }

    // Sign out from Google if signed in
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore errors during sign out
    }

    await ApiClient.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userEmailKey);
  }
}
