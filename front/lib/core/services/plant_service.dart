import 'package:dio/dio.dart';
import 'package:planto/core/models/plant.dart';
import 'package:planto/core/services/api_client.dart';

/// Service for plant API operations.
/// Uses ApiClient with automatic token refresh.
class PlantService {
  late final Dio _dio;
  PlantService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all plants for the current user
  Future<List<Plant>> getMyPlants() async {
    return getPlants();
  }

  /// Get all plants with optional filters
  Future<List<Plant>> getPlants({String? roomId, String? status}) async {
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
        return data.map((json) => Plant.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load plants');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expirée');
      }
      throw Exception('Erreur réseau: ${e.message}');
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
    try {
      final response = await _dio.get('/api/v1/plants/$plantId');

      if (response.statusCode == 200) {
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Plant not found');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
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
      throw Exception('Erreur: ${e.message}');
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
      if (wateringIntervalDays != null) data['wateringIntervalDays'] = wateringIntervalDays;
      if (exposure != null) data['exposure'] = exposure;
      if (customSpecies != null) data['customSpecies'] = customSpecies;
      if (speciesId != null) data['speciesId'] = speciesId;
      if (notes != null) data['notes'] = notes;
      if (lastWatered != null) data['lastWatered'] = '${lastWatered.toUtc().toIso8601String().split('.').first}Z';

      final response = await _dio.post('/api/v1/plants', data: data);

      if (response.statusCode == 201) {
        return Plant.fromJson(response.data);
      } else {
        throw Exception('Failed to create plant');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Delete a plant
  Future<void> deletePlant(String plantId) async {
    try {
      await _dio.delete('/api/v1/plants/$plantId');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
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
      if (wateringIntervalDays != null) data['wateringIntervalDays'] = wateringIntervalDays;
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
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Upload a photo for a plant
  Future<Plant> uploadPlantPhoto(String plantId, List<int> bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
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
        final message = e.response?.data['message'] ?? 'Fichier invalide';
        throw Exception(message);
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Create a care log entry (fertilization, pruning, treatment, note)
  Future<void> createCareLog(String plantId, String action, {String? notes}) async {
    try {
      final data = <String, dynamic>{'action': action};
      if (notes != null && notes.isNotEmpty) data['notes'] = notes;
      await _dio.post('/api/v1/plants/$plantId/care-logs', data: data);
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
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
