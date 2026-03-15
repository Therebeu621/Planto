import 'package:dio/dio.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/models/house_member.dart';
import 'package:planto/core/services/api_client.dart';

/// Service for house API operations.
/// Uses ApiClient with automatic token refresh.
class HouseService {
  late final Dio _dio;
  HouseService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all houses for the current user
  Future<List<House>> getMyHouses() async {
    try {
      final response = await _dio.get('/api/v1/houses');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => House.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load houses');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expirée');
      }
      throw Exception('Erreur réseau: ${e.message}');
    }
  }

  /// Get the active house
  Future<House> getActiveHouse() async {
    try {
      final response = await _dio.get('/api/v1/houses/active');

      if (response.statusCode == 200) {
        return House.fromJson(response.data);
      } else {
        throw Exception('No active house');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Switch active house
  Future<House> switchActiveHouse(String houseId) async {
    try {
      final response = await _dio.put('/api/v1/houses/$houseId/activate');

      if (response.statusCode == 200) {
        return House.fromJson(response.data);
      } else {
        throw Exception('Failed to switch house');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Create a new house
  Future<House> createHouse(String name) async {
    try {
      final response = await _dio.post(
        '/api/v1/houses',
        data: {'name': name},
      );

      if (response.statusCode == 201) {
        return House.fromJson(response.data);
      } else {
        throw Exception('Failed to create house');
      }
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Join a house with invite code
  Future<House> joinHouse(String inviteCode) async {
    try {
      final response = await _dio.post(
        '/api/v1/houses/join',
        data: {'inviteCode': inviteCode},
      );

      if (response.statusCode == 200) {
        return House.fromJson(response.data);
      } else {
        throw Exception('Failed to join house');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Code d\'invitation invalide');
      }
      if (e.response?.statusCode == 400) {
        throw Exception('Vous êtes déjà membre de cette maison');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Leave a house
  Future<void> leaveHouse(String houseId) async {
    try {
      await _dio.delete('/api/v1/houses/$houseId/leave');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Impossible de quitter (vous êtes le seul propriétaire)');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Delete a house (Owner only)
  Future<void> deleteHouse(String houseId) async {
    try {
      await _dio.delete('/api/v1/houses/$houseId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Seul le propriétaire peut supprimer la maison');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  // ==================== MEMBER MANAGEMENT ====================

  /// Get all members of a house
  Future<List<HouseMember>> getHouseMembers(String houseId) async {
    try {
      final response = await _dio.get('/api/v1/houses/$houseId/members');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => HouseMember.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load members');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Vous n\'etes pas membre de cette maison');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Update a member's role (Owner only)
  Future<HouseMember> updateMemberRole(String houseId, String userId, String newRole) async {
    try {
      final response = await _dio.put(
        '/api/v1/houses/$houseId/members/$userId/role',
        data: {'role': newRole},
      );

      if (response.statusCode == 200) {
        return HouseMember.fromJson(response.data);
      } else {
        throw Exception('Failed to update role');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Seul le proprietaire peut modifier les roles');
      }
      if (e.response?.statusCode == 400) {
        final message = e.response?.data?['message'] ?? 'Action impossible';
        throw Exception(message);
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Remove a member from a house (Owner only)
  Future<void> removeMember(String houseId, String userId) async {
    try {
      await _dio.delete('/api/v1/houses/$houseId/members/$userId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Seul le proprietaire peut exclure des membres');
      }
      if (e.response?.statusCode == 400) {
        throw Exception('Vous ne pouvez pas vous exclure vous-meme');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }
}
