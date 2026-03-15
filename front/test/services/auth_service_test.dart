import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/services/api_client.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late AuthService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = AuthService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  // ===================== Token helper methods =====================

  group('getToken', () {
    test('returns null when no token saved', () async {
      final token = await service.getToken();
      expect(token, isNull);
    });

    test('returns token when saved via ApiClient', () async {
      await ApiClient.saveTokens('access_tok', 'refresh_tok');
      final token = await service.getToken();
      expect(token, 'access_tok');
    });
  });

  group('getUserEmail', () {
    test('returns null when no email saved', () async {
      final email = await service.getUserEmail();
      expect(email, isNull);
    });

    test('returns saved email', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', 'test@example.com');
      final email = await service.getUserEmail();
      expect(email, 'test@example.com');
    });
  });

  group('getUserId', () {
    test('returns null when no token', () async {
      final id = await service.getUserId();
      expect(id, isNull);
    });

    test('decodes sub claim from valid JWT', () async {
      // Build a fake JWT: header.payload.signature
      final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
      final payload = base64Url.encode(utf8.encode('{"sub":"user123","email":"a@b.com"}'));
      final fakeJwt = '$header.$payload.fakesignature';

      await ApiClient.saveTokens(fakeJwt, 'refresh');
      final id = await service.getUserId();
      expect(id, 'user123');
    });

    test('returns null for malformed token (not 3 parts)', () async {
      await ApiClient.saveTokens('not.ajwt', 'refresh');
      final id = await service.getUserId();
      expect(id, isNull);
    });

    test('returns null for token with invalid base64 payload', () async {
      await ApiClient.saveTokens('a.!!!invalid!!!.c', 'refresh');
      final id = await service.getUserId();
      expect(id, isNull);
    });

    test('returns null when payload has no sub claim', () async {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(utf8.encode('{"email":"a@b.com"}'));
      final fakeJwt = '$header.$payload.sig';

      await ApiClient.saveTokens(fakeJwt, 'refresh');
      final id = await service.getUserId();
      expect(id, isNull);
    });
  });

  group('isLoggedIn', () {
    test('returns false when no token', () async {
      final result = await service.isLoggedIn();
      expect(result, isFalse);
    });

    test('returns true when token exists', () async {
      await ApiClient.saveTokens('some_token', 'refresh');
      final result = await service.isLoggedIn();
      expect(result, isTrue);
    });

    test('returns false after clearTokens', () async {
      await ApiClient.saveTokens('tok', 'ref');
      await ApiClient.clearTokens();
      final result = await service.isLoggedIn();
      expect(result, isFalse);
    });
  });

  // ===================== Login =====================

  group('login', () {
    test('DioException 401 throws email ou mot de passe incorrect', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/login',
        isError: true,
        errorStatusCode: 401,
        data: {'message': 'Unauthorized'},
      );

      expect(
        () => service.login('bad@email.com', 'wrongpass'),
        throwsA(predicate((e) =>
          e is Exception &&
          e.toString().contains('Email ou mot de passe incorrect'))),
      );
    });

    test('DioException 500 throws erreur de connexion', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/login',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      expect(
        () => service.login('a@b.com', 'pass'),
        throwsA(predicate((e) =>
          e is Exception &&
          e.toString().contains('Erreur de connexion'))),
      );
    });
  });

  // ===================== Register =====================

  group('register', () {
    test('DioException 409 throws cet email est déjà utilisé', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/register',
        isError: true,
        errorStatusCode: 409,
        data: {'message': 'Conflict'},
      );

      expect(
        () => service.register('dup@email.com', 'pass', 'Name'),
        throwsA(predicate((e) =>
          e is Exception &&
          e.toString().contains('Cet email est déjà utilisé'))),
      );
    });

    test('DioException 500 throws erreur lors de l inscription', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/register',
        isError: true,
        errorStatusCode: 500,
        data: {'message': 'Server error'},
      );

      expect(
        () => service.register('a@b.com', 'pass', 'Name'),
        throwsA(predicate((e) =>
          e is Exception &&
          e.toString().contains("Erreur lors de l'inscription"))),
      );
    });
  });

  // ===================== Forgot Password =====================

  group('forgotPassword', () {
    test('success completes without error', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password',
        data: {},
        statusCode: 200,
      );

      await expectLater(service.forgotPassword('a@b.com'), completes);
    });

    test('sends correct email in request body', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password',
        data: {},
        statusCode: 200,
      );

      await service.forgotPassword('test@example.com');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['email'], 'test@example.com');
    });

    test('DioException throws erreur', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/forgot-password',
        isError: true,
        errorStatusCode: 500,
      );

      expect(
        () => service.forgotPassword('a@b.com'),
        throwsA(predicate((e) =>
          e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  // ===================== Reset Password =====================

  group('resetPassword', () {
    test('success with 200 completes without error', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/reset-password',
        data: {},
        statusCode: 200,
      );

      await expectLater(
        service.resetPassword('a@b.com', '123456', 'newpass'),
        completes,
      );
    });

    test('sends correct data in request body', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/reset-password',
        data: {},
        statusCode: 200,
      );

      await service.resetPassword('a@b.com', 'CODE', 'newp');
      final request = mockInterceptor.capturedRequests.last;
      expect(request.data['email'], 'a@b.com');
      expect(request.data['code'], 'CODE');
      expect(request.data['newPassword'], 'newp');
    });

    test('DioException 400 throws code invalide', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/reset-password',
        isError: true,
        errorStatusCode: 400,
        data: {'message': 'Bad request'},
      );

      expect(
        () => service.resetPassword('a@b.com', 'bad', 'newp'),
        throwsA(predicate((e) =>
          e is Exception && e.toString().contains('Code invalide'))),
      );
    });

    test('DioException 500 throws erreur', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/reset-password',
        isError: true,
        errorStatusCode: 500,
      );

      expect(
        () => service.resetPassword('a@b.com', 'code', 'newp'),
        throwsA(predicate((e) =>
          e is Exception && e.toString().contains('Erreur'))),
      );
    });
  });

  // ===================== Logout =====================

  group('logout', () {
    test('clears tokens and email from SharedPreferences', () async {
      // Pre-populate tokens and email
      await ApiClient.saveTokens('tok', 'ref');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', 'a@b.com');

      await service.logout();

      final token = await ApiClient.getAccessToken();
      expect(token, isNull);
      expect(prefs.getString('user_email'), isNull);
    });
  });

  // ==================== Non-200 status branches ====================

  group('login - non-200 status', () {
    test('non-200 status throws login failed', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/login',
          data: {}, statusCode: 500);
      expect(() => service.login('a@b.com', 'pass'), throwsException);
    });

    test('success 200 saves tokens and returns email', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/login',
          data: {'accessToken': 'tok', 'refreshToken': 'ref'});
      final email = await service.login('test@test.com', 'password');
      expect(email, 'test@test.com');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_email'), 'test@test.com');
    });
  });

  group('register - non-201 status', () {
    test('non-201 status throws registration failed', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/register',
          data: {}, statusCode: 500);
      expect(() => service.register('a@b.com', 'pass', 'Name'), throwsException);
    });

    test('success 201 saves tokens and returns email', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/register',
          data: {'accessToken': 'tok', 'refreshToken': 'ref'}, statusCode: 201);
      final email = await service.register('test@test.com', 'password', 'Test');
      expect(email, 'test@test.com');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_email'), 'test@test.com');
    });
  });

  group('resetPassword - non-200 status', () {
    test('non-200 status throws exception', () async {
      mockInterceptor.addMockResponse('/api/v1/auth/reset-password',
          data: {}, statusCode: 500);
      expect(
        () => service.resetPassword('a@b.com', 'code', 'newp'),
        throwsException,
      );
    });
  });
}
