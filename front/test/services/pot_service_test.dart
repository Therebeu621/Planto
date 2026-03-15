import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/pot_stock.dart';
import 'package:planto/core/models/plant.dart';
import 'package:planto/core/services/pot_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late PotService service;

  final potStockJson = {
    'id': 'ps1',
    'diameterCm': 14.0,
    'quantity': 3,
  };

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
    service = PotService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getPotStock', () {
    test('success returns list of pot stock', () async {
      mockInterceptor.addMockResponse('/api/v1/pots', data: [potStockJson]);
      final result = await service.getPotStock();
      expect(result, isA<List<PotStock>>());
      expect(result.length, 1);
      expect(result.first.id, 'ps1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/pots',
          isError: true, errorStatusCode: 500);
      expect(() => service.getPotStock(), throwsException);
    });
  });

  group('getAvailablePots', () {
    test('success returns list of available pots', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/available',
          data: [potStockJson]);
      final result = await service.getAvailablePots();
      expect(result.length, 1);
      expect(result.first.id, 'ps1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/available',
          isError: true, errorStatusCode: 500);
      expect(() => service.getAvailablePots(), throwsException);
    });
  });

  group('addToStock', () {
    test('success with label returns pot stock', () async {
      mockInterceptor.addMockResponse('/api/v1/pots',
          data: potStockJson, statusCode: 201);
      final result = await service.addToStock(
        diameterCm: 14.0,
        quantity: 3,
        label: 'Big pot',
      );
      expect(result.id, 'ps1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['diameterCm'], 14.0);
      expect(request.data['quantity'], 3);
      expect(request.data['label'], 'Big pot');
    });

    test('success without label returns pot stock', () async {
      mockInterceptor.addMockResponse('/api/v1/pots',
          data: potStockJson, statusCode: 201);
      final result = await service.addToStock(diameterCm: 14.0);
      expect(result.id, 'ps1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data.containsKey('label'), false);
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/pots',
          isError: true, errorStatusCode: 500);
      expect(
          () => service.addToStock(diameterCm: 14.0), throwsException);
    });
  });

  group('updateStock', () {
    test('success returns updated pot stock', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/ps1',
          data: potStockJson);
      final result = await service.updateStock('ps1', 5);
      expect(result.id, 'ps1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['quantity'], 5);
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/ps1',
          isError: true, errorStatusCode: 500);
      expect(() => service.updateStock('ps1', 5), throwsException);
    });
  });

  group('deleteStock', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/ps1');
      await service.deleteStock('ps1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/pots/ps1'));
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/ps1',
          isError: true, errorStatusCode: 500);
      expect(() => service.deleteStock('ps1'), throwsException);
    });
  });

  group('repotPlant', () {
    test('success returns plant', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/repot/p1',
          data: plantJson);
      final result = await service.repotPlant('p1', 18.0, notes: 'Bigger pot');
      expect(result, isA<Plant>());
      expect(result.id, 'p1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['newDiameterCm'], 18.0);
      expect(request.data['notes'], 'Bigger pot');
    });

    test('400 error throws pot not available', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/repot/p1',
          isError: true, errorStatusCode: 400);
      expect(
        () => service.repotPlant('p1', 18.0),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Pot non disponible'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/repot/p1',
          isError: true, errorStatusCode: 500);
      expect(() => service.repotPlant('p1', 18.0), throwsException);
    });
  });

  group('getSuggestedPots', () {
    test('success returns list of pot stock', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/suggestions/p1',
          data: [potStockJson]);
      final result = await service.getSuggestedPots('p1');
      expect(result.length, 1);
      expect(result.first.id, 'ps1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/suggestions/p1',
          isError: true, errorStatusCode: 500);
      expect(() => service.getSuggestedPots('p1'), throwsException);
    });
  });

  group('non-200 status branches', () {
    test('getPotStock non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/pots',
          data: [], statusCode: 500);
      expect(() => service.getPotStock(), throwsException);
    });

    test('addPotStock non-201 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/pots',
          data: {}, statusCode: 500);
      expect(() => service.addToStock(diameterCm: 14.0, quantity: 3), throwsException);
    });

    test('updatePotStock non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/pot1',
          data: {}, statusCode: 500);
      expect(() => service.updateStock('pot1', 5), throwsException);
    });

    test('repotPlant non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/repot/p1',
          data: {}, statusCode: 500);
      expect(() => service.repotPlant('p1', 14.0), throwsException);
    });

    test('getSuggestedPots non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/pots/suggestions/p1',
          data: [], statusCode: 500);
      expect(() => service.getSuggestedPots('p1'), throwsException);
    });
  });
}
