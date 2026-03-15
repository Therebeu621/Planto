import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/services/garden_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late GardenService service;

  final cultureJson = {
    'id': 'c1',
    'name': 'Tomatoes',
    'status': 'GROWING',
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = GardenService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getCultures', () {
    test('success returns list of cultures', () async {
      mockInterceptor.addMockResponse('/api/v1/garden/house/h1',
          data: [cultureJson]);
      final result = await service.getCultures('h1');
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, 1);
      expect(result.first['id'], 'c1');
      expect(result.first['name'], 'Tomatoes');
    });

    test('success with status filter', () async {
      mockInterceptor.addMockResponse('/api/v1/garden/house/h1',
          data: [cultureJson]);
      final result = await service.getCultures('h1', status: 'GROWING');
      expect(result.length, 1);
      final request = mockInterceptor.capturedRequests.last;
      expect(request.queryParameters['status'], 'GROWING');
    });

    test('returns empty list on error', () async {
      mockInterceptor.addMockResponse('/api/v1/garden/house/h1',
          isError: true, errorStatusCode: 500);
      final result = await service.getCultures('h1');
      expect(result, isEmpty);
    });
  });

  group('createCulture', () {
    test('success returns culture data', () async {
      mockInterceptor.addMockResponse('/api/v1/garden/house/h1',
          data: cultureJson);
      final result = await service.createCulture(
          'h1', {'name': 'Tomatoes', 'type': 'VEGETABLE'});
      expect(result['id'], 'c1');
      expect(result['name'], 'Tomatoes');
    });
  });

  group('updateStatus', () {
    test('success returns updated culture', () async {
      mockInterceptor.addMockResponse('/api/v1/garden/c1/status',
          data: cultureJson);
      final result =
          await service.updateStatus('c1', {'status': 'HARVESTED'});
      expect(result['id'], 'c1');
    });
  });

  group('deleteCulture', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/garden/c1');
      await service.deleteCulture('c1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/garden/c1'));
    });
  });

  group('non-200 status branches', () {
    test('getCultures non-200 returns empty', () async {
      mockInterceptor.addMockResponse('/api/v1/garden/house/h1',
          data: [], statusCode: 500);
      final result = await service.getCultures('h1');
      expect(result, isEmpty);
    });
  });
}
