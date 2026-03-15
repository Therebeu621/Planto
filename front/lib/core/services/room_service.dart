import 'package:dio/dio.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/services/api_client.dart';

/// Service for room API operations.
/// Uses ApiClient with automatic token refresh.
class RoomService {
  late final Dio _dio;
  RoomService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all rooms with their plants
  Future<List<Room>> getRooms({bool includePlants = true}) async {
    try {
      final response = await _dio.get(
        '/api/v1/rooms',
        queryParameters: {'includePlants': includePlants},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Room.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load rooms');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      }
      throw Exception('Erreur réseau: ${e.message}');
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
      throw Exception('Erreur réseau: ${e.message}');
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
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Delete a room (must be empty)
  Future<void> deleteRoom(String roomId) async {
    try {
      await _dio.delete('/api/v1/rooms/$roomId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('La piece contient encore des plantes');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Piece non trouvee');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }
}
