import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/models/user_profile.dart';
import 'package:planto/core/services/profile_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late ProfileService service;

  final userJson = {
    'id': 'u1',
    'email': 'test@test.com',
    'displayName': 'Test',
    'role': 'MEMBER',
  };

  final statsJson = {
    'totalPlants': 5,
    'wateringsThisMonth': 10,
    'wateringStreak': 3,
    'healthyPlantsPercentage': 80,
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = ProfileService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getCurrentUser', () {
    test('success returns user profile', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: userJson);
      final result = await service.getCurrentUser();
      expect(result, isA<UserProfile>());
      expect(result.id, 'u1');
      expect(result.email, 'test@test.com');
      expect(result.displayName, 'Test');
    });

    test('401 error throws session expired', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me',
          isError: true, errorStatusCode: 401);
      expect(
        () => service.getCurrentUser(),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('Session expiree'))),
      );
    });

    test('DioException throws network error', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.getCurrentUser(),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  group('getUserStats', () {
    test('success returns user stats', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/stats',
          data: statsJson);
      final result = await service.getUserStats();
      expect(result, isA<UserStats>());
      expect(result.totalPlants, 5);
      expect(result.wateringsThisMonth, 10);
      expect(result.wateringStreak, 3);
      expect(result.healthyPlantsPercentage, 80);
    });

    test('401 error throws session expired', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/stats',
          isError: true, errorStatusCode: 401);
      expect(
        () => service.getUserStats(),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('Session expiree'))),
      );
    });
  });

  group('updateProfile', () {
    test('success returns updated profile', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me', data: userJson);
      final result = await service.updateProfile(displayName: 'Updated');
      expect(result.id, 'u1');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['displayName'], 'Updated');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me',
          isError: true, errorStatusCode: 500);
      expect(
          () => service.updateProfile(displayName: 'Updated'),
          throwsException);
    });
  });

  group('changePassword', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/password');
      await service.changePassword(
        currentPassword: 'old',
        newPassword: 'new',
      );
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['currentPassword'], 'old');
      expect(request.data['newPassword'], 'new');
    });

    test('401 error throws wrong password', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/password',
          isError: true, errorStatusCode: 401);
      expect(
        () => service.changePassword(
            currentPassword: 'wrong', newPassword: 'new'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Mot de passe actuel incorrect'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/password',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.changePassword(
            currentPassword: 'old', newPassword: 'new'),
        throwsException,
      );
    });
  });

  group('deleteAccount', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me');
      await service.deleteAccount();
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me',
          isError: true, errorStatusCode: 500);
      expect(() => service.deleteAccount(), throwsException);
    });
  });

  group('uploadProfilePhotoBytes', () {
    test('success returns user profile', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo',
          data: userJson);
      final result =
          await service.uploadProfilePhotoBytes([1, 2, 3], 'photo.jpg');
      expect(result.id, 'u1');
    });

    test('400 error throws file invalid message', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo',
          isError: true,
          errorStatusCode: 400,
          data: {'message': 'Fichier trop volumineux'});
      expect(
        () => service.uploadProfilePhotoBytes([1, 2, 3], 'photo.jpg'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Fichier trop volumineux'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo',
          isError: true, errorStatusCode: 500);
      expect(
        () => service.uploadProfilePhotoBytes([1, 2, 3], 'photo.jpg'),
        throwsException,
      );
    });
  });

  group('deleteProfilePhoto', () {
    test('success returns user profile', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo',
          data: userJson);
      final result = await service.deleteProfilePhoto();
      expect(result.id, 'u1');
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo',
          isError: true, errorStatusCode: 500);
      expect(() => service.deleteProfilePhoto(), throwsException);
    });
  });

  group('verifyEmail', () {
    test('success returns user profile', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/verify-email',
          data: userJson);
      final result = await service.verifyEmail('123456');
      expect(result.id, 'u1');
    });

    test('400 error throws invalid code', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/verify-email',
          isError: true, errorStatusCode: 400);
      expect(
        () => service.verifyEmail('000000'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Code invalide'))),
      );
    });

    test('generic error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/verify-email',
          isError: true, errorStatusCode: 500);
      expect(() => service.verifyEmail('123456'), throwsException);
    });
  });

  group('resendVerification', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/resend-verification');
      await service.resendVerification();
    });

    test('error throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/resend-verification',
          isError: true, errorStatusCode: 500);
      expect(() => service.resendVerification(), throwsException);
    });
  });

  group('getProfilePhotoFullUrl', () {
    test('returns null for null path', () {
      expect(service.getProfilePhotoFullUrl(null), isNull);
    });

    test('returns null for empty path', () {
      expect(service.getProfilePhotoFullUrl(''), isNull);
    });

    test('returns full URL for valid path', () {
      final result = service.getProfilePhotoFullUrl('/uploads/photo.jpg');
      expect(result, isNotNull);
      expect(result, contains('/uploads/photo.jpg'));
    });
  });

  group('non-200 status branches', () {
    test('getMyProfile non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me',
          data: {}, statusCode: 500);
      expect(() => service.getCurrentUser(), throwsException);
    });

    test('getMyStats non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/stats',
          data: {}, statusCode: 500);
      expect(() => service.getUserStats(), throwsException);
    });

    test('updateProfile non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me',
          data: {}, statusCode: 500);
      expect(() => service.updateProfile(displayName: 'X'), throwsException);
    });

    test('uploadProfilePhoto non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo',
          data: {}, statusCode: 500);
      expect(
        () => service.uploadProfilePhotoBytes([1, 2, 3], 'photo.jpg'),
        throwsException,
      );
    });

    test('deleteProfilePhoto non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/me/photo',
          data: {}, statusCode: 500);
      expect(() => service.deleteProfilePhoto(), throwsException);
    });

    test('verifyEmail non-200 throws', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/verify-email',
          data: {}, statusCode: 500);
      expect(() => service.verifyEmail('123456'), throwsException);
    });
  });
}
