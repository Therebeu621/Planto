import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/api_client.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient.saveTokens', () {
    test('stores both tokens in SharedPreferences', () async {
      await ApiClient.saveTokens('access123', 'refresh456');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'access123');
      expect(prefs.getString('refresh_token'), 'refresh456');
    });

    test('overwrites existing tokens', () async {
      await ApiClient.saveTokens('old_access', 'old_refresh');
      await ApiClient.saveTokens('new_access', 'new_refresh');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'new_access');
      expect(prefs.getString('refresh_token'), 'new_refresh');
    });
  });

  group('ApiClient.clearTokens', () {
    test('removes both tokens', () async {
      await ApiClient.saveTokens('a', 'r');
      await ApiClient.clearTokens();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    });

    test('does not throw when no tokens exist', () async {
      await expectLater(ApiClient.clearTokens(), completes);
    });
  });

  group('ApiClient.getAccessToken', () {
    test('returns token when saved', () async {
      await ApiClient.saveTokens('mytoken', 'refresh');
      final token = await ApiClient.getAccessToken();
      expect(token, 'mytoken');
    });

    test('returns null when no token saved', () async {
      final token = await ApiClient.getAccessToken();
      expect(token, isNull);
    });

    test('returns null after clearTokens', () async {
      await ApiClient.saveTokens('tok', 'ref');
      await ApiClient.clearTokens();
      final token = await ApiClient.getAccessToken();
      expect(token, isNull);
    });
  });

  group('ApiClient.instance', () {
    test('returns same instance (singleton)', () {
      final a = ApiClient.instance;
      final b = ApiClient.instance;
      expect(identical(a, b), isTrue);
    });

    test('has a non-null dio instance', () {
      expect(ApiClient.instance.dio, isNotNull);
    });

    test('dio has interceptors configured', () {
      final interceptors = ApiClient.instance.dio.interceptors;
      expect(interceptors, isNotEmpty);
    });
  });

  group('ApiClient token round-trip', () {
    test('save then get returns the same access token', () async {
      await ApiClient.saveTokens('abc123', 'def456');
      final token = await ApiClient.getAccessToken();
      expect(token, 'abc123');
    });

    test('save, clear, save new, get returns new token', () async {
      await ApiClient.saveTokens('first', 'ref1');
      await ApiClient.clearTokens();
      await ApiClient.saveTokens('second', 'ref2');
      final token = await ApiClient.getAccessToken();
      expect(token, 'second');
    });
  });
}
