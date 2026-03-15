import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/services/species_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late SpeciesService service;

  final plantResultJson = {
    'nomFrancais': 'Monstera',
    'nomLatin': 'Monstera deliciosa',
    'arrosageFrequenceJours': 7,
    'luminosite': 'Mi-ombre',
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = SpeciesService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('searchPlants', () {
    test('success returns list of PlantResult', () async {
      mockInterceptor.addMockResponse('/api/v1/species/search',
          data: [plantResultJson]);
      final result = await service.searchPlants('mons');
      expect(result, isA<List<PlantResult>>());
      expect(result.length, 1);
      expect(result.first.nomFrancais, 'Monstera');
      expect(result.first.nomLatin, 'Monstera deliciosa');
      expect(result.first.arrosageFrequenceJours, 7);
    });

    test('short query returns empty list', () async {
      final result = await service.searchPlants('m');
      expect(result, isEmpty);
      expect(mockInterceptor.capturedRequests, isEmpty);
    });

    test('DioException returns empty list', () async {
      mockInterceptor.addMockResponse('/api/v1/species/search',
          isError: true, errorStatusCode: 500);
      final result = await service.searchPlants('mons');
      expect(result, isEmpty);
    });
  });

  group('getPlantByName', () {
    test('success returns PlantResult', () async {
      mockInterceptor.addMockResponse('/api/v1/species/by-name',
          data: plantResultJson);
      final result = await service.getPlantByName('Monstera');
      expect(result, isNotNull);
      expect(result!.nomFrancais, 'Monstera');
    });

    test('empty name returns null', () async {
      final result = await service.getPlantByName('');
      expect(result, isNull);
      expect(mockInterceptor.capturedRequests, isEmpty);
    });

    test('DioException returns null', () async {
      mockInterceptor.addMockResponse('/api/v1/species/by-name',
          isError: true, errorStatusCode: 500);
      final result = await service.getPlantByName('Monstera');
      expect(result, isNull);
    });
  });

  group('getDatabaseStatus', () {
    test('success returns status map', () async {
      mockInterceptor.addMockResponse('/api/v1/species/status',
          data: {'status': 'ok', 'plantCount': 150});
      final result = await service.getDatabaseStatus();
      expect(result['status'], 'ok');
      expect(result['plantCount'], 150);
    });

    test('error returns error status', () async {
      mockInterceptor.addMockResponse('/api/v1/species/status',
          isError: true, errorStatusCode: 500);
      final result = await service.getDatabaseStatus();
      expect(result['status'], 'error');
      expect(result['plantCount'], 0);
    });
  });

  group('PlantResult', () {
    test('fromJson parses correctly', () {
      final result = PlantResult.fromJson(plantResultJson);
      expect(result.nomFrancais, 'Monstera');
      expect(result.nomLatin, 'Monstera deliciosa');
      expect(result.arrosageFrequenceJours, 7);
      expect(result.luminosite, 'Mi-ombre');
    });

    test('fromJson with missing fields uses defaults', () {
      final result = PlantResult.fromJson({});
      expect(result.nomFrancais, '');
      expect(result.nomLatin, '');
      expect(result.arrosageFrequenceJours, 7);
      expect(result.luminosite, 'Mi-ombre');
    });

    test('getExposureValue returns SUN for Plein soleil', () {
      final result = PlantResult.fromJson({
        ...plantResultJson,
        'luminosite': 'Plein soleil',
      });
      expect(result.getExposureValue(), 'SUN');
    });

    test('getExposureValue returns SHADE for Ombre', () {
      final result = PlantResult.fromJson({
        ...plantResultJson,
        'luminosite': 'Ombre',
      });
      expect(result.getExposureValue(), 'SHADE');
    });

    test('getExposureValue returns PARTIAL_SHADE for Mi-ombre', () {
      final result = PlantResult.fromJson(plantResultJson);
      expect(result.getExposureValue(), 'PARTIAL_SHADE');
    });

    test('getExposureValue returns PARTIAL_SHADE for unknown value', () {
      final result = PlantResult.fromJson({
        ...plantResultJson,
        'luminosite': 'Unknown',
      });
      expect(result.getExposureValue(), 'PARTIAL_SHADE');
    });

    test('displayName returns nomFrancais', () {
      final result = PlantResult.fromJson(plantResultJson);
      expect(result.displayName, 'Monstera');
    });

    test('description returns nomLatin', () {
      final result = PlantResult.fromJson(plantResultJson);
      expect(result.description, 'Monstera deliciosa');
    });
  });

  group('non-200 status branches', () {
    test('searchSpecies non-200 returns empty', () async {
      mockInterceptor.addMockResponse('/api/v1/species/search',
          data: [], statusCode: 500);
      final result = await service.searchPlants('test');
      expect(result, isEmpty);
    });

    test('getDatabaseStatus non-200 returns error', () async {
      mockInterceptor.addMockResponse('/api/v1/species/status',
          data: {}, statusCode: 500);
      final result = await service.getDatabaseStatus();
      expect(result['status'], 'error');
    });
  });
}
