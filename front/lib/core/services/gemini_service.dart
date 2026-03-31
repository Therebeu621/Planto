import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/models/plant_identification_result.dart';

/// Service pour l'identification de plantes via Google Gemini AI
class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _client;
  final String _apiKey;

  GeminiService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? AppConstants.geminiApiKey;

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
    if (_apiKey.isEmpty) {
      throw GeminiException(
        "Cle Gemini absente dans le front. Relancez l'application avec --dart-define=GEMINI_API_KEY=...",
      );
    }

    final base64Image = base64Encode(imageBytes);

    final url = Uri.parse(
      '$_baseUrl/${AppConstants.geminiModel}:generateContent?key=$_apiKey',
    );

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': _systemPrompt},
            {
              'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'topK': 32,
        'topP': 1,
        'maxOutputTokens': 4096,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    };

    try {
      debugPrint('GeminiService: Envoi de la requete...');

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('GeminiService: Status ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('GeminiService: Erreur - ${response.body}');

        try {
          final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
          final error = errorJson['error'];
          if (error is Map<String, dynamic>) {
            final apiMessage = error['message'] as String?;
            if (apiMessage != null && apiMessage.isNotEmpty) {
              throw GeminiException(apiMessage);
            }
          } else if (error is String && error.isNotEmpty) {
            throw GeminiException(error);
          }
        } on FormatException {
          // Fall back to a generic status-based message when the body is not JSON.
        }

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

      // Gemini 2.5+ peut inclure des "thought" parts — on cherche le dernier part avec du texte
      String? textResponse;
      for (final part in parts.reversed) {
        final text = part['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          textResponse = text;
          break;
        }
      }
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

  /// Genere des conseils de culture pour une plante a une etape donnee
  ///
  /// [plantName] - Nom de la plante (ex: "Tomate")
  /// [variety] - Variete optionnelle (ex: "Coeur de boeuf")
  /// [status] - Etape actuelle (SEMIS, GERMINATION, CROISSANCE, FLORAISON, RECOLTE)
  /// [sowDate] - Date de semis (pour calculer l'anciennete)
  /// Returns Map avec les cles: conseils, duree_estimee_jours, arrosage, temperature, erreurs_courantes
  Future<Map<String, dynamic>> getGardenAdvice({
    required String plantName,
    String? variety,
    required String status,
    String? sowDate,
    String? notes,
  }) async {
    final plantDesc = variety != null && variety.isNotEmpty
        ? '$plantName ($variety)'
        : plantName;

    final statusLabels = {
      'SEMIS': 'Semis (graines viennent d\'etre plantees)',
      'GERMINATION': 'Germination (les premieres pousses apparaissent)',
      'CROISSANCE': 'Croissance (la plante grandit activement)',
      'FLORAISON': 'Floraison (la plante fleurit)',
      'RECOLTE': 'Recolte (prete a etre recoltee)',
    };

    final prompt =
        '''
Tu es un expert jardinier. Donne des conseils pratiques pour cette plante a cette etape.

Plante: $plantDesc
Etape actuelle: ${statusLabels[status] ?? status}
${sowDate != null ? 'Date de semis: $sowDate' : ''}
${notes != null && notes.isNotEmpty ? 'Notes du jardinier: $notes' : ''}

Renvoie UNIQUEMENT un JSON valide (sans markdown, sans backticks) avec ces cles exactes:
{
  "conseils": "3-4 conseils pratiques et concrets pour cette etape, separes par des retours a la ligne",
  "duree_estimee_jours": 14,
  "arrosage_conseil": "Frequence et quantite d'arrosage recommandee pour cette etape",
  "temperature_ideale": "Plage de temperature ideale (ex: 18-25°C)",
  "erreurs_courantes": "2-3 erreurs frequentes a eviter a cette etape",
  "prochaine_etape_signe": "Signe concret qui indique qu'il faut passer a l'etape suivante"
}

IMPORTANT:
- duree_estimee_jours doit etre un entier (nombre de jours typiques pour cette etape pour cette plante)
- Sois concis et pratique, pas de blabla
- Adapte les conseils a la plante specifique
''';

    final url = Uri.parse(
      '$_baseUrl/${AppConstants.geminiModel}:generateContent?key=$_apiKey',
    );

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'topK': 32,
        'topP': 1,
        'maxOutputTokens': 4096,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    };

    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw GeminiException('Erreur API Gemini: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiException('Aucune reponse de l\'IA');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw GeminiException('Reponse vide');
      }

      // Gemini 2.5+ peut inclure des "thought" parts — on cherche le dernier part avec du texte
      String? textResponse;
      for (final part in parts.reversed) {
        final text = part['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          textResponse = text;
          break;
        }
      }
      if (textResponse == null || textResponse.isEmpty) {
        throw GeminiException('Reponse vide');
      }

      debugPrint('GeminiService: Reponse brute advice - $textResponse');

      String cleanJson = textResponse.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Erreur: $e');
    }
  }

  /// Chatbot jardinier — repond aux questions avec le contexte des plantes/cultures de l'utilisateur
  ///
  /// [userMessage] - Le message de l'utilisateur
  /// [conversationHistory] - Historique des messages precedents (role + text)
  /// [plantsContext] - Resume des plantes de l'utilisateur
  /// [culturesContext] - Resume des cultures du potager
  Future<String> chat({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
    String plantsContext = '',
    String culturesContext = '',
  }) async {
    final systemPrompt =
        '''
Tu es Planto, un assistant jardinier intelligent et sympathique. Tu aides l'utilisateur a prendre soin de ses plantes d'interieur et de son potager.

Tu connais toutes les plantes et cultures de l'utilisateur. Voici leur inventaire :

=== PLANTES D'INTERIEUR ===
${plantsContext.isNotEmpty ? plantsContext : 'Aucune plante enregistree.'}

=== POTAGER (CULTURES) ===
${culturesContext.isNotEmpty ? culturesContext : 'Aucune culture en cours.'}

REGLES:
- Reponds toujours en francais
- Sois concis et pratique (pas de blabla)
- Utilise les donnees de l'utilisateur pour personnaliser tes reponses
- Si on te demande combien de plantes a arroser, regarde les donnees "needsWatering" ou "nextWateringDate"
- Tu peux donner des conseils, diagnostiquer des problemes, suggerer des actions
- Sois sympathique et encourageant
- Si la question n'a rien a voir avec les plantes/jardinage, reponds quand meme poliment mais ramene vers le sujet
- IMPORTANT: Tu es un assistant en LECTURE SEULE. Tu ne peux PAS ajouter, supprimer, modifier ou arroser des plantes. Si l'utilisateur te demande d'effectuer une action (ajouter une plante, arroser, supprimer, renommer, etc.), explique-lui gentiment qu'il doit le faire lui-meme dans l'application et guide-le vers la bonne fonctionnalite. Ne pretends JAMAIS avoir effectue une action.
''';

    // Construire l'historique de conversation pour Gemini
    final contents = <Map<String, dynamic>>[];

    // System prompt comme premier message user
    contents.add({
      'role': 'user',
      'parts': [
        {'text': systemPrompt},
      ],
    });
    contents.add({
      'role': 'model',
      'parts': [
        {
          'text':
              'Compris ! Je suis Planto, ton assistant jardinier. Je connais tes plantes et ton potager. Comment puis-je t\'aider ?',
        },
      ],
    });

    // Ajouter l'historique
    for (final msg in conversationHistory) {
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['text'] ?? ''},
        ],
      });
    }

    // Ajouter le nouveau message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage},
      ],
    });

    final url = Uri.parse(
      '$_baseUrl/${AppConstants.geminiModel}:generateContent?key=$_apiKey',
    );

    final requestBody = {
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    };

    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('GeminiService chat error: ${response.body}');
        throw GeminiException('Erreur API Gemini: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiException('Aucune reponse');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw GeminiException('Reponse vide');
      }

      // Chercher le dernier part avec du texte (skip thinking parts)
      String? textResponse;
      for (final part in parts.reversed) {
        final text = part['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          textResponse = text;
          break;
        }
      }

      return textResponse ?? 'Desole, je n\'ai pas pu generer de reponse.';
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Erreur: $e');
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
