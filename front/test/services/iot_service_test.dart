import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/services/iot_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late IotService service;

  final sensorJson = {
    'id': 's1',
    'name': 'Humidity Sensor',
    'type': 'HUMIDITY',
  };

  final readingJson = {
    'id': 'rd1',
    'sensorId': 's1',
    'value': 45.0,
    'timestamp': '2026-01-01T00:00:00Z',
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = IotService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getSensorsByHouse', () {
    test('success returns list of sensors', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/house/h1/sensors',
          data: [sensorJson]);
      final result = await service.getSensorsByHouse('h1');
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, 1);
      expect(result.first['id'], 's1');
    });

    test('error returns empty list', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/house/h1/sensors',
          isError: true, errorStatusCode: 500);
      final result = await service.getSensorsByHouse('h1');
      expect(result, isEmpty);
    });
  });

  group('getSensorsByPlant', () {
    test('success returns list of sensors', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/plant/p1/sensors',
          data: [sensorJson]);
      final result = await service.getSensorsByPlant('p1');
      expect(result.length, 1);
      expect(result.first['id'], 's1');
    });

    test('error returns empty list', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/plant/p1/sensors',
          isError: true, errorStatusCode: 500);
      final result = await service.getSensorsByPlant('p1');
      expect(result, isEmpty);
    });
  });

  group('createSensor', () {
    test('success returns sensor data', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/house/h1/sensors',
          data: sensorJson);
      final result = await service.createSensor(
          'h1', {'name': 'Humidity Sensor', 'type': 'HUMIDITY'});
      expect(result['id'], 's1');
      expect(result['name'], 'Humidity Sensor');
    });
  });

  group('getReadings', () {
    test('success returns list of readings', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/sensors/s1/readings',
          data: [readingJson]);
      final result = await service.getReadings('s1');
      expect(result.length, 1);
      expect(result.first['id'], 'rd1');
      expect(result.first['value'], 45.0);
    });

    test('error returns empty list', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/sensors/s1/readings',
          isError: true, errorStatusCode: 500);
      final result = await service.getReadings('s1');
      expect(result, isEmpty);
    });
  });

  group('deleteSensor', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/sensors/s1');
      await service.deleteSensor('s1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/iot/sensors/s1'));
    });
  });

  group('non-200 status branches', () {
    test('getSensors non-200 returns empty', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/house/h1/sensors',
          data: [], statusCode: 500);
      final result = await service.getSensorsByHouse('h1');
      expect(result, isEmpty);
    });

    test('getSensorsByPlant non-200 returns empty', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/plant/p1/sensors',
          data: [], statusCode: 500);
      final result = await service.getSensorsByPlant('p1');
      expect(result, isEmpty);
    });

    test('getReadings non-200 returns empty', () async {
      mockInterceptor.addMockResponse('/api/v1/iot/sensors/s1/readings',
          data: [], statusCode: 500);
      final result = await service.getReadings('s1');
      expect(result, isEmpty);
    });
  });
}
