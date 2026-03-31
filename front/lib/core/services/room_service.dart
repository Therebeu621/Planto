import 'package:dio/dio.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/services/api_client.dart';
import 'package:planto/core/services/cache_service.dart';
import 'package:planto/core/utils/api_error_formatter.dart';

/// Service for room API operations.
/// Uses ApiClient with automatic token refresh.
/// Supporte le mode hors-ligne via cache local.
class RoomService {
  late final Dio _dio;
  final CacheService _cache = CacheService.instance;

  /// Indique si la dernière requête a été servie depuis le cache
  bool lastRequestFromCache = false;

  RoomService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all rooms with their plants
  Future<List<Room>> getRooms({bool includePlants = true}) async {
    const cacheKey = 'rooms_with_plants';
    lastRequestFromCache = false;

    try {
      final response = await _dio.get(
        '/api/v1/rooms',
        queryParameters: {'includePlants': includePlants},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        await _cache.putList(cacheKey, data);
        return data.map((json) => Room.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load rooms');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      }
      // Mode hors-ligne
      final cached = await _cache.getList(cacheKey);
      if (cached != null) {
        lastRequestFromCache = true;
        return cached
            .map((json) => Room.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de charger les pieces'),
      );
    }
  }

  /// Get a single room by ID
  Future<Room> getRoomById(String roomId) async {
    try {
      final response = await _dio.get('/api/v1/rooms/$roomId');

      if (response.statusCode == 200) {
        return Room.fromJson(response.data);
      } else {
        throw Exception('Room not found');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Pièce non trouvée');
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de charger la piece'),
      );
    }
  }

  /// Create a new room
  Future<Room> createRoom(String name, String type) async {
    try {
      final response = await _dio.post(
        '/api/v1/rooms',
        data: {'name': name, 'type': type},
      );

      if (response.statusCode == 201) {
        return Room.fromJson(response.data);
      } else {
        throw Exception('Failed to create room');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception(
          'Vous devez rejoindre une maison avant de creer une piece',
        );
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de creer la piece'),
      );
    }
  }

  /// Delete a room (must be empty)
  Future<void> deleteRoom(String roomId) async {
    try {
      await _dio.delete('/api/v1/rooms/$roomId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Piece non trouvee');
      }
      if (e.response?.statusCode == 403) {
        throw Exception('Vous n\'avez pas acces a cette piece');
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de supprimer la piece'),
      );
    }
  }
}
