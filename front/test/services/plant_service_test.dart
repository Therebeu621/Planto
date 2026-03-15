import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/plant.dart';
import 'package:planto/core/services/plant_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late PlantService service;

  final plantJson = {
    'id': 'p1',
    'nickname': 'Test',
    'needsWatering': false,
    'isSick': false,
    'isWilted': false,
    'needsRepotting': false,
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = PlantService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getPlants', () {
    test('success returns list of plants', () async {
      mockInterceptor.addMockResponse('/api/v1/plants', data: [plantJson]);
      final result = await service.getPlants();
      expect(result, isA<List<Plant>>());
      expect(result.length, 1);
      expect(result.first.id, 'p1');
      expect(result.first.nickname, 'Test');
    });

    test('with filters passes query params', () async {
      mockInterceptor.addMockResponse('/api/v1/plants', data: [plantJson]);
      await service.getPlants(roomId: 'r1', status: 'healthy');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.queryParameters['roomId'], 'r1');
      expect(request.queryParameters['status'], 'healthy');
    });

    test('401 error throws session expired', () async {
      mockInterceptor.addMockResponse('/api/v1/plants',
          isError: true, errorStatusCode: 401);
      expect(
        () => service.getPlants(),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('Session expir'))),
      );
    });

    test('DioException throws network error', () async {
      mockInterceptor.addMockResponse('/api/v1/plants',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.getPlants(),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  group('getMyPlants', () {
    test('calls getPlants and returns plants', () async {
      mockInterceptor.addMockResponse('/api/v1/plants', data: [plantJson]);
      final result = await service.getMyPlants();
      expect(result.length, 1);
      expect(result.first.id, 'p1');
    });
  });

  group('searchPlants', () {
    test('success returns list of plants', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/search',
          data: [plantJson]);
      final result = await service.searchPlants('test');
      expect(result.length, 1);
      expect(result.first.id, 'p1');
    });

    test('short query returns empty list', () async {
      final result = await service.searchPlants('a');
      expect(result, isEmpty);
      expect(mockInterceptor.capturedRequests, isEmpty);
    });

    test('DioException returns empty list', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/search',
          isError: true, errorStatusCode: 500);
      final result = await service.searchPlants('test');
      expect(result, isEmpty);
    });
  });

  group('getPlantById', () {
    test('success returns plant', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1', data: plantJson);
      final result = await service.getPlantById('p1');
      expect(result.id, 'p1');
      expect(result.nickname, 'Test');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          isError: true, errorStatusCode: 404);
      expect(() => service.getPlantById('p1'), throwsException);
    });
  });

  group('waterPlant', () {
    test('success returns plant', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/water',
          data: plantJson);
      final result = await service.waterPlant('p1');
      expect(result.id, 'p1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/water',
          isError: true, errorStatusCode: 500);
      expect(() => service.waterPlant('p1'), throwsException);
    });
  });

  group('createPlant', () {
    test('success with all params returns plant', () async {
      mockInterceptor.addMockResponse('/api/v1/plants',
          data: plantJson, statusCode: 201);
      final result = await service.createPlant(
        nickname: 'Test',
        roomId: 'r1',
        photoUrl: 'http://photo.jpg',
        wateringIntervalDays: 7,
        exposure: 'SUN',
        customSpecies: 'Custom',
        speciesId: 's1',
        notes: 'Some notes',
        isSick: true,
        isWilted: false,
        needsRepotting: true,
        potDiameterCm: 14.0,
        lastWatered: DateTime(2026, 1, 1),
      );
      expect(result.id, 'p1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['nickname'], 'Test');
      expect(request.data['roomId'], 'r1');
      expect(request.data['wateringIntervalDays'], 7);
      expect(request.data['exposure'], 'SUN');
      expect(request.data['customSpecies'], 'Custom');
      expect(request.data['speciesId'], 's1');
      expect(request.data['notes'], 'Some notes');
      expect(request.data['isSick'], true);
      expect(request.data['needsRepotting'], true);
      expect(request.data['potDiameterCm'], 14.0);
    });

    test('success with minimal params returns plant', () async {
      mockInterceptor.addMockResponse('/api/v1/plants',
          data: plantJson, statusCode: 201);
      final result = await service.createPlant(nickname: 'Test');
      expect(result.id, 'p1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['nickname'], 'Test');
      expect(request.data.containsKey('roomId'), false);
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants',
          isError: true, errorStatusCode: 500);
      expect(() => service.createPlant(nickname: 'Test'), throwsException);
    });
  });

  group('deletePlant', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1');
      await service.deletePlant('p1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/plants/p1'));
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          isError: true, errorStatusCode: 500);
      expect(() => service.deletePlant('p1'), throwsException);
    });
  });

  group('updatePlant', () {
    test('success returns updated plant', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1', data: plantJson);
      final result = await service.updatePlant(
        plantId: 'p1',
        nickname: 'Updated',
        roomId: 'r2',
        isSick: true,
        potDiameterCm: 20.0,
      );
      expect(result.id, 'p1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['nickname'], 'Updated');
      expect(request.data['roomId'], 'r2');
      expect(request.data['isSick'], true);
      expect(request.data['potDiameterCm'], 20.0);
    });

    test('404 error throws plant not found', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          isError: true, errorStatusCode: 404);
      expect(
        () => service.updatePlant(plantId: 'p1'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Plante non trouvee'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.updatePlant(plantId: 'p1'),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  group('uploadPlantPhoto', () {
    test('success returns plant', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photo',
          data: plantJson);
      final result =
          await service.uploadPlantPhoto('p1', [1, 2, 3], 'photo.jpg');
      expect(result.id, 'p1');
    });

    test('400 error throws file invalid message', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photo',
          isError: true,
          errorStatusCode: 400,
          data: {'message': 'Fichier trop volumineux'});
      expect(
        () => service.uploadPlantPhoto('p1', [1, 2, 3], 'photo.jpg'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Fichier trop volumineux'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photo',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.uploadPlantPhoto('p1', [1, 2, 3], 'photo.jpg'),
        throwsException,
      );
    });
  });

  group('createCareLog', () {
    test('success with notes completes', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/care-logs');
      await service.createCareLog('p1', 'WATER', notes: 'Extra water');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['action'], 'WATER');
      expect(request.data['notes'], 'Extra water');
    });

    test('success without notes completes', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/care-logs');
      await service.createCareLog('p1', 'FERTILIZE');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['action'], 'FERTILIZE');
      expect(request.data.containsKey('notes'), false);
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/care-logs',
          isError: true, errorStatusCode: 500);
      expect(
          () => service.createCareLog('p1', 'WATER'), throwsException);
    });
  });

  group('deletePlantPhoto', () {
    test('success returns plant', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photo',
          data: plantJson);
      final result = await service.deletePlantPhoto('p1');
      expect(result.id, 'p1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photo',
          isError: true, errorStatusCode: 500);
      expect(() => service.deletePlantPhoto('p1'), throwsException);
    });
  });

  // ==================== Else-branch (non-200 statusCode) tests ====================

  group('getPlants - non-200 status', () {
    test('non-200 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants',
          data: [], statusCode: 500);
      expect(() => service.getPlants(), throwsException);
    });
  });

  group('searchPlants - non-200 status', () {
    test('non-200 status returns empty list', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/search',
          data: [], statusCode: 500);
      final result = await service.searchPlants('test');
      expect(result, isEmpty);
    });
  });

  group('getPlantById - non-200 status', () {
    test('non-200 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          data: {}, statusCode: 500);
      expect(() => service.getPlantById('p1'), throwsException);
    });
  });

  group('waterPlant - non-200 status', () {
    test('non-200 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/water',
          data: {}, statusCode: 500);
      expect(() => service.waterPlant('p1'), throwsException);
    });
  });

  group('createPlant - non-200 status', () {
    test('non-201 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants',
          data: {}, statusCode: 500);
      expect(() => service.createPlant(nickname: 'Test'), throwsException);
    });
  });

  group('updatePlant - non-200 status', () {
    test('non-200 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1',
          data: {}, statusCode: 500);
      expect(() => service.updatePlant(plantId: 'p1'), throwsException);
    });
  });

  group('uploadPlantPhoto - non-200 status', () {
    test('non-200 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photo',
          data: {}, statusCode: 500);
      expect(
        () => service.uploadPlantPhoto('p1', [1, 2, 3], 'photo.jpg'),
        throwsException,
      );
    });
  });

  group('deletePlantPhoto - non-200 status', () {
    test('non-200 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photo',
          data: {}, statusCode: 500);
      expect(() => service.deletePlantPhoto('p1'), throwsException);
    });
  });
}
