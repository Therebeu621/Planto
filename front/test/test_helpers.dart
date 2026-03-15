import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock interceptor that returns predefined responses for Dio requests.
class MockDioInterceptor extends Interceptor {
  final Map<String, MockResponse> _responses = {};
  final List<RequestOptions> capturedRequests = [];

  void addMockResponse(String pathPattern, {
    dynamic data,
    int statusCode = 200,
    bool isError = false,
    int? errorStatusCode,
  }) {
    _responses[pathPattern] = MockResponse(
      data: data ?? {},
      statusCode: statusCode,
      isError: isError,
      errorStatusCode: errorStatusCode,
    );
  }

  void clearResponses() {
    _responses.clear();
    capturedRequests.clear();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    capturedRequests.add(options);

    // Find matching response
    for (final entry in _responses.entries) {
      if (options.path.contains(entry.key)) {
        final mock = entry.value;
        if (mock.isError) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: mock.errorStatusCode ?? 500,
              data: mock.data,
            ),
            type: DioExceptionType.badResponse,
            message: 'Mock error',
          ));
          return;
        }
        handler.resolve(Response(
          requestOptions: options,
          data: mock.data,
          statusCode: mock.statusCode,
        ));
        return;
      }
    }

    // Default: resolve with empty response
    handler.resolve(Response(
      requestOptions: options,
      data: {},
      statusCode: 200,
    ));
  }
}

class MockResponse {
  final dynamic data;
  final int statusCode;
  final bool isError;
  final int? errorStatusCode;

  MockResponse({
    required this.data,
    required this.statusCode,
    this.isError = false,
    this.errorStatusCode,
  });
}

/// Create a Dio instance with mock interceptor for testing
Dio createMockDio(MockDioInterceptor mockInterceptor) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
  dio.interceptors.add(mockInterceptor);
  return dio;
}

/// Initialize SharedPreferences for testing
Future<void> initTestPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
}
