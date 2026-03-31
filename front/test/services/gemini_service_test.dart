import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:planto/core/services/gemini_service.dart';

void main() {
  GeminiService buildService(http.Client client) {
    return GeminiService(client: client, apiKey: 'test-key');
  }

  // Helper to build a Gemini-style JSON response body
  String buildGeminiResponse(String textContent) {
    return jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': textContent},
            ],
          },
        },
      ],
    });
  }

  // Valid plant JSON that Gemini would return
  const validPlantJson =
      '{'
      '"petit_nom": "Mon Pilea",'
      '"espece": "Pilea peperomioides",'
      '"arrosage_jours": 7,'
      '"luminosite": "Mi-ombre",'
      '"description": "Une jolie plante"'
      '}';

  final fakeImageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

  // ===================== GeminiException =====================

  group('GeminiException', () {
    test('stores message', () {
      final e = GeminiException('test error');
      expect(e.message, 'test error');
    });

    test('toString returns message', () {
      final e = GeminiException('something failed');
      expect(e.toString(), 'something failed');
    });
  });

  // ===================== identifyPlant =====================

  group('identifyPlant', () {
    test('success with valid JSON response', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(buildGeminiResponse(validPlantJson), 200);
      });

      final service = buildService(mockClient);
      final result = await service.identifyPlant(fakeImageBytes);

      expect(result.petitNom, 'Mon Pilea');
      expect(result.espece, 'Pilea peperomioides');
      expect(result.arrosageJours, 7);
      expect(result.luminosite, 'Mi-ombre');
      expect(result.description, 'Une jolie plante');
    });

    test('success with markdown-wrapped JSON (```json ... ```)', () async {
      final wrappedJson = '```json\n$validPlantJson\n```';
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(buildGeminiResponse(wrappedJson), 200);
      });

      final service = buildService(mockClient);
      final result = await service.identifyPlant(fakeImageBytes);

      expect(result.petitNom, 'Mon Pilea');
      expect(result.espece, 'Pilea peperomioides');
    });

    test('success with markdown-wrapped JSON (``` ... ```)', () async {
      final wrappedJson = '```\n$validPlantJson\n```';
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(buildGeminiResponse(wrappedJson), 200);
      });

      final service = buildService(mockClient);
      final result = await service.identifyPlant(fakeImageBytes);

      expect(result.petitNom, 'Mon Pilea');
    });

    test('non-200 status throws GeminiException', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('{"error": {"message": "bad request"}}', 400);
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('bad request'),
          ),
        ),
      );
    });

    test('empty candidates throws GeminiException', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(jsonEncode({'candidates': []}), 200);
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('Aucune reponse'),
          ),
        ),
      );
    });

    test('null candidates throws GeminiException', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(jsonEncode({'candidates': null}), 200);
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('Aucune reponse'),
          ),
        ),
      );
    });

    test('empty parts throws GeminiException', () async {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {'parts': []},
          },
        ],
      });
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(body, 200);
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('Reponse vide'),
          ),
        ),
      );
    });

    test('null text in parts throws GeminiException', () async {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': null},
              ],
            },
          },
        ],
      });
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(body, 200);
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('Texte de reponse vide'),
          ),
        ),
      );
    });

    test('empty text in parts throws GeminiException', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(buildGeminiResponse(''), 200);
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('Texte de reponse vide'),
          ),
        ),
      );
    });

    test('invalid JSON in response text throws GeminiException', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(buildGeminiResponse('not valid json {{{'), 200);
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('Impossible de parser'),
          ),
        ),
      );
    });

    test('network error throws GeminiException', () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception('Network unreachable');
      });

      final service = buildService(mockClient);

      expect(
        () => service.identifyPlant(fakeImageBytes),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.message,
            'message',
            contains('Erreur de connexion'),
          ),
        ),
      );
    });

    test('sends base64 encoded image in request body', () async {
      late Map<String, dynamic> capturedBody;
      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(buildGeminiResponse(validPlantJson), 200);
      });

      final service = buildService(mockClient);
      await service.identifyPlant(fakeImageBytes);

      final contents = capturedBody['contents'] as List;
      final parts = contents[0]['parts'] as List;
      final inlineData = parts[1]['inline_data'] as Map<String, dynamic>;
      expect(inlineData['mime_type'], 'image/jpeg');
      expect(inlineData['data'], base64Encode(fakeImageBytes));
    });

    test('uses default values for missing JSON fields', () async {
      const minimalJson = '{"petit_nom": "Test"}';
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(buildGeminiResponse(minimalJson), 200);
      });

      final service = buildService(mockClient);
      final result = await service.identifyPlant(fakeImageBytes);

      expect(result.petitNom, 'Test');
      expect(result.espece, 'Espece inconnue');
      expect(result.arrosageJours, 7);
      expect(result.luminosite, 'Mi-ombre');
      expect(result.description, '');
    });
  });
}
