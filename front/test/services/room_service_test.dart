import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/services/room_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late RoomService service;

  final roomJson = {
    'id': 'r1',
    'name': 'Salon',
    'type': 'LIVING_ROOM',
    'plantCount': 2,
    'plants': [],
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = RoomService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getRooms', () {
    test('success returns list of rooms', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms', data: [roomJson]);
      final result = await service.getRooms();
      expect(result, isA<List<Room>>());
      expect(result.length, 1);
      expect(result.first.id, 'r1');
      expect(result.first.name, 'Salon');
    });

    test('401 error throws session expired', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms',
          isError: true, errorStatusCode: 401);
      expect(
        () => service.getRooms(),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('Session expir'))),
      );
    });

    test('DioException throws network error', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.getRooms(),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  group('getRoomById', () {
    test('success returns room', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1', data: roomJson);
      final result = await service.getRoomById('r1');
      expect(result.id, 'r1');
      expect(result.name, 'Salon');
    });

    test('404 error throws room not found', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1',
          isError: true, errorStatusCode: 404);
      expect(
        () => service.getRoomById('r1'),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('non trouv'))),
      );
    });

    test('generic error throws network error', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.getRoomById('r1'),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  group('createRoom', () {
    test('success returns room', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms',
          data: roomJson, statusCode: 201);
      final result = await service.createRoom('Salon', 'LIVING_ROOM');
      expect(result.id, 'r1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['name'], 'Salon');
      expect(request.data['type'], 'LIVING_ROOM');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms',
          isError: true, errorStatusCode: 500);
      expect(
          () => service.createRoom('Salon', 'LIVING_ROOM'), throwsException);
    });
  });

  group('deleteRoom', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1');
      await service.deleteRoom('r1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/rooms/r1'));
    });

    test('400 error throws room not empty', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1',
          isError: true, errorStatusCode: 400);
      expect(
        () => service.deleteRoom('r1'),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('plantes'))),
      );
    });

    test('404 error throws room not found', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1',
          isError: true, errorStatusCode: 404);
      expect(
        () => service.deleteRoom('r1'),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('non trouvee'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1',
          isError: true, errorStatusCode: 500);
      expect(() => service.deleteRoom('r1'), throwsException);
    });
  });

  // ==================== Else-branch (non-200 statusCode) tests ====================

  group('non-200 status branches', () {
    test('getRooms non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms',
          data: [], statusCode: 500);
      expect(() => service.getRooms(), throwsException);
    });

    test('getRoomById non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms/r1',
          data: {}, statusCode: 500);
      expect(() => service.getRoomById('r1'), throwsException);
    });

    test('createRoom non-201 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/rooms',
          data: {}, statusCode: 500);
      expect(() => service.createRoom('Test', 'BEDROOM'), throwsException);
    });
  });
}
