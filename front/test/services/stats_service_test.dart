import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/services/stats_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late StatsService service;

  final dashboardJson = {
    'totalPlants': 10,
    'healthyPlants': 8,
    'wateringsToday': 3,
  };

  final annualJson = {
    'year': 2026,
    'totalWaterings': 120,
    'monthlyData': [],
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = StatsService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getDashboard', () {
    test('success returns dashboard data', () async {
      mockInterceptor.addMockResponse('/api/v1/stats/dashboard',
          data: dashboardJson);
      final result = await service.getDashboard();
      expect(result['totalPlants'], 10);
      expect(result['healthyPlants'], 8);
      expect(result['wateringsToday'], 3);
    });

    test('returns empty map on non-200 status', () async {
      mockInterceptor.addMockResponse('/api/v1/stats/dashboard',
          data: dashboardJson, statusCode: 204);
      final result = await service.getDashboard();
      expect(result, isEmpty);
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/stats/dashboard',
          isError: true, errorStatusCode: 500);
      expect(() => service.getDashboard(), throwsException);
    });
  });

  group('getAnnualStats', () {
    test('success returns annual stats', () async {
      mockInterceptor.addMockResponse('/api/v1/stats/annual',
          data: annualJson);
      final result = await service.getAnnualStats();
      expect(result['year'], 2026);
      expect(result['totalWaterings'], 120);
    });

    test('success with year param', () async {
      mockInterceptor.addMockResponse('/api/v1/stats/annual',
          data: annualJson);
      await service.getAnnualStats(year: 2025);
      final request = mockInterceptor.capturedRequests.last;
      expect(request.queryParameters['year'], 2025);
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/stats/annual',
          isError: true, errorStatusCode: 500);
      expect(() => service.getAnnualStats(), throwsException);
    });
  });

  group('non-200 status branches', () {
    test('getStats non-200 returns empty', () async {
      mockInterceptor.addMockResponse('/api/v1/stats/dashboard',
          data: {}, statusCode: 500);
      final result = await service.getDashboard();
      expect(result, isEmpty);
    });
  });
}
