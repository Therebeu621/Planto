import 'package:dio/dio.dart';
import 'package:planto/core/models/care_log.dart';
import 'package:planto/core/models/plant.dart';
import 'package:planto/core/services/api_client.dart';
import 'package:planto/core/services/cache_service.dart';
import 'package:planto/core/utils/api_error_formatter.dart';

/// Service for plant API operations.
/// Uses ApiClient with automatic token refresh.
/// Supporte le mode hors-ligne via cache local.
class PlantService {
  late final Dio _dio;
  final CacheService _cache = CacheService.instance;

  /// Indique si la dernière requête a été servie depuis le cache
  bool lastRequestFromCache = false;

  PlantService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all plants for the current user
  Future<List<Plant>> getMyPlants() async {
    return getPlants();
  }

  /// Get all plants with optional filters
  Future<List<Plant>> getPlants({String? roomId, String? status}) async {
    final cacheKey = 'plants_${roomId ?? 'all'}_${status ?? 'all'}';
    lastRequestFromCache = false;

    try {
      final queryParams = <String, dynamic>{};
      if (roomId != null) queryParams['roomId'] = roomId;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/api/v1/plants',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Mise en cache de la réponse brute
        await _cache.putList(cacheKey, data);
        return data.map((json) => Plant.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load plants');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expirée');
      }
      // Mode hors-ligne : tenter le cache
      final cached = await _cache.getList(cacheKey);
      if (cached != null) {
        lastRequestFromCache = true;
        return cached
            .map((json) => Plant.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de charger les plantes'),
      );
    }
  }

  /// Search plants by nickname
  Future<List<Plant>> searchPlants(String query) async {
    if (query.length < 2) return [];

    try {
      final response = await _dio.get(
        '/api/v1/plants/search',
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Plant.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException {
      return [];
    }
  }

  /// Get a single plant by ID
  Future<Plant> getPlantById(String plantId) async {
    final cacheKey = 'plant_$plantId';
    lastRequestFromCache = false;

    try {
      final response = await _dio.get('/api/v1/plants/$plantId');

      if (response.statusCode == 200) {
        await _cache.putObject(cacheKey, response.data as Map<String, dynamic>);
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Plant not found');
      }
    } on DioException catch (e) {
      // Mode hors-ligne
      final cached = await _cache.getObject(cacheKey);
      if (cached != null) {
        lastRequestFromCache = true;
        return Plant.fromJson(cached);
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de charger la plante'),
      );
    }
  }

  /// Water a plant
  Future<Plant> waterPlant(String plantId) async {
    try {
      final response = await _dio.post('/api/v1/plants/$plantId/water');

      if (response.statusCode == 200) {
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Failed to water plant');
      }
    } on DioException catch (e) {
      final formatted = formatApiError(
        e,
        fallbackMessage: 'Impossible d\'arroser la plante',
      );
      if (e.response?.statusCode == 403 &&
          formatted.toLowerCase() == "you don't have access to this plant") {
        throw Exception(
          'Vous ne pouvez pas arroser cette plante sans delegation vacances active',
        );
      }
      throw Exception(
        formatted,
      );
    }
  }

  /// Create a new plant
  Future<Plant> createPlant({
    required String nickname,
    String? roomId,
    String? photoUrl,
    int? wateringIntervalDays,
    String? exposure,
    String? customSpecies,
    String? speciesId,
    String? notes,
    bool isSick = false,
    bool isWilted = false,
    bool needsRepotting = false,
    double? potDiameterCm,
    DateTime? lastWatered,
  }) async {
    try {
      final data = <String, dynamic>{
        'nickname': nickname,
        'isSick': isSick,
        'isWilted': isWilted,
        'needsRepotting': needsRepotting,
      };
      if (roomId != null) data['roomId'] = roomId;
      if (potDiameterCm != null) data['potDiameterCm'] = potDiameterCm;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (wateringIntervalDays != null)
        data['wateringIntervalDays'] = wateringIntervalDays;
      if (exposure != null) data['exposure'] = exposure;
      if (customSpecies != null) data['customSpecies'] = customSpecies;
      if (speciesId != null) data['speciesId'] = speciesId;
      if (notes != null) data['notes'] = notes;
      if (lastWatered != null)
        data['lastWatered'] =
            '${lastWatered.toUtc().toIso8601String().split('.').first}Z';

      final response = await _dio.post('/api/v1/plants', data: data);

      if (response.statusCode == 201) {
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Failed to create plant');
      }
    } on DioException catch (e) {
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de creer la plante'),
      );
    }
  }

  /// Delete a plant
  Future<void> deletePlant(String plantId) async {
    try {
      await _dio.delete('/api/v1/plants/$plantId');
    } on DioException catch (e) {
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de supprimer la plante'),
      );
    }
  }

  /// Update an existing plant
  Future<Plant> updatePlant({
    required String plantId,
    String? nickname,
    String? roomId,
    String? photoUrl,
    int? wateringIntervalDays,
    String? exposure,
    String? notes,
    bool? isSick,
    bool? isWilted,
    bool? needsRepotting,
    double? potDiameterCm,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (nickname != null) data['nickname'] = nickname;
      if (potDiameterCm != null) data['potDiameterCm'] = potDiameterCm;
      if (roomId != null) data['roomId'] = roomId;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (wateringIntervalDays != null)
        data['wateringIntervalDays'] = wateringIntervalDays;
      if (exposure != null) data['exposure'] = exposure;
      if (notes != null) data['notes'] = notes;
      if (isSick != null) data['isSick'] = isSick;
      if (isWilted != null) data['isWilted'] = isWilted;
      if (needsRepotting != null) data['needsRepotting'] = needsRepotting;

      final response = await _dio.put('/api/v1/plants/$plantId', data: data);

      if (response.statusCode == 200) {
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Failed to update plant');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Plante non trouvee');
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de modifier la plante'),
      );
    }
  }

  /// Upload a photo for a plant
  Future<Plant> uploadPlantPhoto(
    String plantId,
    List<int> bytes,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await _dio.post(
        '/api/v1/plants/$plantId/photo',
        data: formData,
      );

      if (response.statusCode == 200) {
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Failed to upload photo');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(formatApiError(e, fallbackMessage: 'Fichier invalide'));
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible d\'envoyer la photo'),
      );
    }
  }

  /// Get all care logs for a plant, with optional action filter
  Future<List<CareLog>> getCareLogs(String plantId, {String? action}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (action != null) queryParams['action'] = action;

      final response = await _dio.get(
        '/api/v1/plants/$plantId/care-logs',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => CareLog.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load care logs');
      }
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de charger l\'historique des soins',
        ),
      );
    }
  }

  /// Create a care log entry (fertilization, pruning, treatment, note)
  Future<void> createCareLog(
    String plantId,
    String action, {
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{'action': action};
      if (notes != null && notes.isNotEmpty) data['notes'] = notes;
      await _dio.post('/api/v1/plants/$plantId/care-logs', data: data);
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible d\'ajouter cette action',
        ),
      );
    }
  }

  /// Delete a note-type care log
  Future<void> deleteCareLog(String plantId, String logId) async {
    try {
      await _dio.delete('/api/v1/plants/$plantId/care-logs/$logId');
    } on DioException catch (e) {
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de supprimer ce memo'),
      );
    }
  }

  /// Delete plant photo
  Future<Plant> deletePlantPhoto(String plantId) async {
    try {
      final response = await _dio.delete('/api/v1/plants/$plantId/photo');

      if (response.statusCode == 200) {
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Failed to delete photo');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }
}
