import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/models/plant_identification_result.dart';

/// Service pour l'identification de plantes via Google Gemini AI
class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _client;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  /// Prompt systeme pour l'identification de plantes
  static const String _systemPrompt = '''
Tu es un expert botaniste. Analyse cette image. Identifie la plante.
Renvoie UNIQUEMENT un JSON valide (sans markdown, sans backticks, sans texte supplementaire) avec ces cles exactes correspondant a mon formulaire :
{
  "petit_nom": "Suggestion de nom affectueux (ex: Mon Pilea, Fifi le Ficus)",
  "espece": "Nom scientifique et commun (ex: Pilea peperomioides - Plante monnaie chinoise)",
  "arrosage_jours": 7,
  "luminosite": "Mi-ombre",
  "description": "Courte description fun en francais (2-3 phrases)"
}

IMPORTANT:
- arrosage_jours doit etre un entier (frequence en jours, ex: 7 pour une fois par semaine)
- luminosite doit etre STRICTEMENT une de ces valeurs: "Plein soleil", "Mi-ombre", "Ombre"
- Si tu ne peux pas identifier la plante, renvoie un JSON avec petit_nom="Plante mysterieuse" et des valeurs par defaut
''';

  /// Identifie une plante a partir d'une image
  ///
  /// [imageBytes] - Les bytes de l'image (JPEG ou PNG)
  /// Returns [PlantIdentificationResult] ou lance une exception
  Future<PlantIdentificationResult> identifyPlant(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final url = Uri.parse('$_baseUrl/${AppConstants.geminiModel}:generateContent?key=${AppConstants.geminiApiKey}');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': _systemPrompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'topK': 32,
        'topP': 1,
        'maxOutputTokens': 1024,
      }
    };

    try {
      debugPrint('GeminiService: Envoi de la requete...');

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('GeminiService: Status ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('GeminiService: Erreur - ${response.body}');
        throw GeminiException('Erreur API Gemini: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      // Extraire le texte de la reponse
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiException('Aucune reponse de l\'IA');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw GeminiException('Reponse vide de l\'IA');
      }

      final textResponse = parts[0]['text'] as String?;
      if (textResponse == null || textResponse.isEmpty) {
        throw GeminiException('Texte de reponse vide');
      }

      debugPrint('GeminiService: Reponse brute - $textResponse');

      // Parser le JSON de la reponse (enlever les backticks markdown si presents)
      String cleanJson = textResponse.trim();

      // Enlever les marqueurs markdown ```json et ```
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final plantJson = jsonDecode(cleanJson) as Map<String, dynamic>;
      final result = PlantIdentificationResult.fromJson(plantJson);

      debugPrint('GeminiService: Resultat - $result');
      return result;

    } on FormatException catch (e) {
      debugPrint('GeminiService: Erreur de parsing JSON - $e');
      throw GeminiException('Impossible de parser la reponse de l\'IA');
    } catch (e) {
      if (e is GeminiException) rethrow;
      debugPrint('GeminiService: Erreur - $e');
      throw GeminiException('Erreur de connexion: $e');
    }
  }
}

/// Exception personnalisee pour les erreurs Gemini
class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}
