import 'package:dio/dio.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API client with automatic token refresh.
/// All services should use [ApiClient.dio] instead of creating their own Dio instance.
class ApiClient {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio dio;
  bool _isRefreshing = false;
  final List<_RetryRequest> _pendingRequests = [];

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  /// Attach Bearer token to every request.
  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// Intercept 401 errors and attempt token refresh.
  Future<void> _onError(
      DioException error, ErrorInterceptorHandler handler) async {
    if (error.response?.statusCode != 401) {
      return handler.next(error);
    }

    // Don't retry refresh calls themselves
    final path = error.requestOptions.path;
    if (path.contains('/auth/refresh') || path.contains('/auth/login') || path.contains('/auth/register')) {
      return handler.next(error);
    }

    if (_isRefreshing) {
      // Queue this request to be retried after refresh completes
      _pendingRequests.add(_RetryRequest(error.requestOptions, handler));
      return;
    }

    _isRefreshing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        _isRefreshing = false;
        _rejectPending(error);
        return handler.next(error);
      }

      // Call refresh endpoint (use a fresh Dio to avoid interceptor loop)
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['accessToken'] as String;
        final newRefreshToken = response.data['refreshToken'] as String;

        // Persist new tokens
        await prefs.setString(_accessTokenKey, newAccessToken);
        await prefs.setString(_refreshTokenKey, newRefreshToken);

        _isRefreshing = false;

        // Retry the original request
        final retryResponse = await _retry(error.requestOptions, newAccessToken);
        handler.resolve(retryResponse);

        // Retry all queued requests
        _resolvePending(newAccessToken);
      } else {
        _isRefreshing = false;
        _rejectPending(error);
        handler.next(error);
      }
    } catch (_) {
      _isRefreshing = false;
      _rejectPending(error);
      handler.next(error);
    }
  }

  /// Retry a failed request with a new token.
  Future<Response> _retry(RequestOptions options, String newToken) {
    options.headers['Authorization'] = 'Bearer $newToken';
    return dio.fetch(options);
  }

  /// Resolve all pending requests after successful refresh.
  void _resolvePending(String newToken) {
    for (final pending in _pendingRequests) {
      _retry(pending.options, newToken).then(
        (response) => pending.handler.resolve(response),
        onError: (e) => pending.handler.reject(e as DioException),
      );
    }
    _pendingRequests.clear();
  }

  /// Reject all pending requests on refresh failure.
  void _rejectPending(DioException error) {
    for (final pending in _pendingRequests) {
      pending.handler.next(error);
    }
    _pendingRequests.clear();
  }

  // ==================== Token helpers ====================

  /// Save both tokens after login/register.
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  /// Clear tokens on logout.
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  /// Get the current access token.
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }
}

class _RetryRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _RetryRequest(this.options, this.handler);
}
