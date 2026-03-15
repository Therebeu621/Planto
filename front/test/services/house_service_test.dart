import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/models/house_member.dart';
import 'package:planto/core/services/house_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late HouseService service;

  final houseJson = {
    'id': 'h1',
    'name': 'My House',
    'inviteCode': 'ABC123',
    'memberCount': 2,
    'roomCount': 3,
    'isActive': true,
    'role': 'OWNER',
  };

  final memberJson = {
    'userId': 'u1',
    'displayName': 'John',
    'email': 'j@e.com',
    'role': 'MEMBER',
    'joinedAt': '2026-01-01T00:00:00Z',
    'isActive': true,
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = HouseService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getMyHouses', () {
    test('success returns list of houses', () async {
      mockInterceptor.addMockResponse('/api/v1/houses', data: [houseJson]);
      final result = await service.getMyHouses();
      expect(result, isA<List<House>>());
      expect(result.length, 1);
      expect(result.first.id, 'h1');
      expect(result.first.name, 'My House');
    });

    test('401 error throws session expired', () async {
      mockInterceptor.addMockResponse('/api/v1/houses',
          isError: true, errorStatusCode: 401);
      expect(
        () => service.getMyHouses(),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('Session expir'))),
      );
    });

    test('DioException throws network error', () async {
      mockInterceptor.addMockResponse('/api/v1/houses',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.getMyHouses(),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  group('getActiveHouse', () {
    test('success returns house', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/active',
          data: houseJson);
      final result = await service.getActiveHouse();
      expect(result.id, 'h1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/active',
          isError: true, errorStatusCode: 500);
      expect(() => service.getActiveHouse(), throwsException);
    });
  });

  group('switchActiveHouse', () {
    test('success returns house', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/activate',
          data: houseJson);
      final result = await service.switchActiveHouse('h1');
      expect(result.id, 'h1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/activate',
          isError: true, errorStatusCode: 500);
      expect(() => service.switchActiveHouse('h1'), throwsException);
    });
  });

  group('createHouse', () {
    test('success returns house', () async {
      mockInterceptor.addMockResponse('/api/v1/houses',
          data: houseJson, statusCode: 201);
      final result = await service.createHouse('My House');
      expect(result.id, 'h1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['name'], 'My House');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses',
          isError: true, errorStatusCode: 500);
      expect(() => service.createHouse('My House'), throwsException);
    });
  });

  group('joinHouse', () {
    test('success returns house', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/join',
          data: houseJson);
      final result = await service.joinHouse('ABC123');
      expect(result.id, 'h1');
    });

    test('404 error throws invalid invite code', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/join',
          isError: true, errorStatusCode: 404);
      expect(
        () => service.joinHouse('INVALID'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('invitation invalide'))),
      );
    });

    test('400 error throws already member', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/join',
          isError: true, errorStatusCode: 400);
      expect(
        () => service.joinHouse('ABC123'),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('membre'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/join',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.joinHouse('ABC123'),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  group('leaveHouse', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/leave');
      await service.leaveHouse('h1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/houses/h1/leave'));
    });

    test('400 error throws only owner message', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/leave',
          isError: true, errorStatusCode: 400);
      expect(
        () => service.leaveHouse('h1'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('seul propri'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/leave',
          isError: true, errorStatusCode: 500);
      expect(() => service.leaveHouse('h1'), throwsException);
    });
  });

  group('deleteHouse', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1');
      await service.deleteHouse('h1');
    });

    test('403 error throws owner only message', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1',
          isError: true, errorStatusCode: 403);
      expect(
        () => service.deleteHouse('h1'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('propri'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1',
          isError: true, errorStatusCode: 500);
      expect(() => service.deleteHouse('h1'), throwsException);
    });
  });

  group('getHouseMembers', () {
    test('success returns list of members', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members',
          data: [memberJson]);
      final result = await service.getHouseMembers('h1');
      expect(result, isA<List<HouseMember>>());
      expect(result.length, 1);
      expect(result.first.id, 'u1');
      expect(result.first.displayName, 'John');
    });

    test('403 error throws not member message', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members',
          isError: true, errorStatusCode: 403);
      expect(
        () => service.getHouseMembers('h1'),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('pas membre'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members',
          isError: true, errorStatusCode: 500);
      expect(() => service.getHouseMembers('h1'), throwsException);
    });
  });

  group('updateMemberRole', () {
    test('success returns updated member', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1/role',
          data: memberJson);
      final result = await service.updateMemberRole('h1', 'u1', 'ADMIN');
      expect(result.id, 'u1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['role'], 'ADMIN');
    });

    test('403 error throws owner only message', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1/role',
          isError: true, errorStatusCode: 403);
      expect(
        () => service.updateMemberRole('h1', 'u1', 'ADMIN'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('proprietaire'))),
      );
    });

    test('400 error throws action impossible', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1/role',
          isError: true,
          errorStatusCode: 400,
          data: {'message': 'Action impossible'});
      expect(
        () => service.updateMemberRole('h1', 'u1', 'ADMIN'),
        throwsException,
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1/role',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.updateMemberRole('h1', 'u1', 'ADMIN'),
        throwsException,
      );
    });
  });

  group('removeMember', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1');
      await service.removeMember('h1', 'u1');
    });

    test('403 error throws owner only message', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1',
          isError: true, errorStatusCode: 403);
      expect(
        () => service.removeMember('h1', 'u1'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('proprietaire'))),
      );
    });

    test('400 error throws cannot remove self', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1',
          isError: true, errorStatusCode: 400);
      expect(
        () => service.removeMember('h1', 'u1'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('vous-meme'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1',
          isError: true, errorStatusCode: 500);
      expect(() => service.removeMember('h1', 'u1'), throwsException);
    });
  });

  // ==================== Else-branch (non-200 statusCode) tests ====================

  group('non-200 status branches', () {
    test('getMyHouses non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/houses',
          data: [], statusCode: 500);
      expect(() => service.getMyHouses(), throwsException);
    });

    test('getActiveHouse non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/active',
          data: {}, statusCode: 500);
      expect(() => service.getActiveHouse(), throwsException);
    });

    test('switchActiveHouse non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/activate',
          data: {}, statusCode: 500);
      expect(() => service.switchActiveHouse('h1'), throwsException);
    });

    test('createHouse non-201 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/houses',
          data: {}, statusCode: 500);
      expect(() => service.createHouse('Test'), throwsException);
    });

    test('joinHouse non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/join',
          data: {}, statusCode: 500);
      expect(() => service.joinHouse('CODE'), throwsException);
    });

    test('getHouseMembers non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members',
          data: [], statusCode: 500);
      expect(() => service.getHouseMembers('h1'), throwsException);
    });

    test('updateMemberRole non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/u1/role',
          data: {}, statusCode: 500);
      expect(() => service.updateMemberRole('h1', 'u1', 'ADMIN'), throwsException);
    });
  });
}
