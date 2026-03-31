import 'package:dio/dio.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/models/house_invitation.dart';
import 'package:planto/core/models/house_member.dart';
import 'package:planto/core/models/vacation_delegation.dart';
import 'package:planto/core/services/api_client.dart';
import 'package:planto/core/services/cache_service.dart';
import 'package:planto/core/utils/api_error_formatter.dart';

/// Service for house API operations.
/// Uses ApiClient with automatic token refresh.
/// Supporte le mode hors-ligne via cache local.
class HouseService {
  late final Dio _dio;
  final CacheService _cache = CacheService.instance;

  /// Indique si la dernière requête a été servie depuis le cache
  bool lastRequestFromCache = false;

  HouseService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all houses for the current user
  Future<List<House>> getMyHouses() async {
    const cacheKey = 'my_houses';
    lastRequestFromCache = false;

    try {
      final response = await _dio.get('/api/v1/houses');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        await _cache.putList(cacheKey, data);
        return data.map((json) => House.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load houses');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expirée');
      }
      // Mode hors-ligne
      final cached = await _cache.getList(cacheKey);
      if (cached != null) {
        lastRequestFromCache = true;
        return cached
            .map((json) => House.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de charger vos maisons'),
      );
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
      if (e.response?.statusCode == 404) {
        throw Exception('Aucune maison active');
      }
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de charger la maison active',
        ),
      );
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
      if (e.response?.statusCode == 403) {
        throw Exception('Vous n\'etes pas membre de cette maison');
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de changer de maison'),
      );
    }
  }

  /// Create a new house
  Future<House> createHouse(String name) async {
    try {
      final response = await _dio.post('/api/v1/houses', data: {'name': name});

      if (response.statusCode == 201) {
        return House.fromJson(response.data);
      } else {
        throw Exception('Failed to create house');
      }
    } on DioException catch (e) {
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de creer la maison'),
      );
    }
  }

  /// Request to join a house with invite code (creates a pending request)
  Future<HouseInvitation> requestJoinHouse(String inviteCode) async {
    try {
      final response = await _dio.post(
        '/api/v1/houses/join',
        data: {'inviteCode': inviteCode},
      );

      if (response.statusCode == 201) {
        return HouseInvitation.fromJson(response.data);
      } else {
        throw Exception('Failed to send join request');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Code d\'invitation invalide');
      }
      if (e.response?.statusCode == 400) {
        throw Exception(
          formatApiError(
            e,
            fallbackMessage: 'Impossible d\'envoyer la demande',
          ),
        );
      }
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible d\'envoyer la demande',
        ),
      );
    }
  }

  /// Accept a join request (Owner only)
  Future<HouseInvitation> acceptInvitation(String invitationId) async {
    try {
      final response = await _dio.put(
        '/api/v1/houses/invitations/$invitationId/accept',
      );

      if (response.statusCode == 200) {
        return HouseInvitation.fromJson(response.data);
      } else {
        throw Exception('Failed to accept invitation');
      }
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible d\'accepter la demande',
        ),
      );
    }
  }

  /// Decline a join request (Owner only)
  Future<HouseInvitation> declineInvitation(String invitationId) async {
    try {
      final response = await _dio.put(
        '/api/v1/houses/invitations/$invitationId/decline',
      );

      if (response.statusCode == 200) {
        return HouseInvitation.fromJson(response.data);
      } else {
        throw Exception('Failed to decline invitation');
      }
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de refuser la demande',
        ),
      );
    }
  }

  /// Get pending invitations for a house (Owner only)
  Future<List<HouseInvitation>> getPendingInvitations(String houseId) async {
    try {
      final response = await _dio.get('/api/v1/houses/$houseId/invitations');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => HouseInvitation.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de charger les demandes',
        ),
      );
    }
  }

  /// Get my pending join requests
  Future<List<HouseInvitation>> getMyPendingRequests() async {
    try {
      final response = await _dio.get('/api/v1/houses/my-requests');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => HouseInvitation.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de charger vos demandes',
        ),
      );
    }
  }

  /// Leave a house
  Future<void> leaveHouse(String houseId) async {
    try {
      await _dio.delete('/api/v1/houses/$houseId/leave');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(
          formatApiError(
            e,
            fallbackMessage: 'Impossible de quitter cette maison',
          ),
        );
      }
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de quitter cette maison',
        ),
      );
    }
  }

  /// Delete a house (Owner only)
  Future<void> deleteHouse(String houseId) async {
    try {
      await _dio.delete('/api/v1/houses/$houseId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Seul le proprietaire peut supprimer la maison');
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de supprimer la maison'),
      );
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
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de charger les membres'),
      );
    }
  }

  /// Update a member's role (Owner only)
  Future<HouseMember> updateMemberRole(
    String houseId,
    String userId,
    String newRole,
  ) async {
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
        throw Exception(
          formatApiError(e, fallbackMessage: 'Action impossible'),
        );
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible de modifier le role'),
      );
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
        throw Exception(
          formatApiError(e, fallbackMessage: 'Action impossible'),
        );
      }
      throw Exception(
        formatApiError(e, fallbackMessage: 'Impossible d\'exclure ce membre'),
      );
    }
  }

  // ==================== VACATION / DELEGATION ====================

  /// Activate vacation mode (delegate plant care to another member)
  Future<VacationDelegation> activateVacation(
    String houseId, {
    required String delegateId,
    required String startDate,
    required String endDate,
    String? message,
  }) async {
    try {
      final data = <String, dynamic>{
        'delegateId': delegateId,
        'startDate': startDate,
        'endDate': endDate,
      };
      if (message != null && message.isNotEmpty) {
        data['message'] = message;
      }

      final response = await _dio.post(
        '/api/v1/houses/$houseId/vacation',
        data: data,
      );

      if (response.statusCode == 201) {
        return VacationDelegation.fromJson(response.data);
      } else {
        throw Exception('Impossible d\'activer le mode vacances');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(formatApiError(e, fallbackMessage: 'Requete invalide'));
      }
      if (e.response?.statusCode == 403) {
        throw Exception('Vous n\'etes pas membre de cette maison');
      }
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible d\'activer le mode vacances',
        ),
      );
    }
  }

  /// Cancel active vacation
  Future<void> cancelVacation(String houseId) async {
    try {
      await _dio.delete('/api/v1/houses/$houseId/vacation');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Aucune delegation active');
      }
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible d\'annuler le mode vacances',
        ),
      );
    }
  }

  /// Get current vacation status (returns null if no active vacation)
  Future<VacationDelegation?> getVacationStatus(String houseId) async {
    try {
      final response = await _dio.get('/api/v1/houses/$houseId/vacation');

      if (response.statusCode == 200 && response.data != null) {
        return VacationDelegation.fromJson(response.data);
      }
      return null; // 204 No Content
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de charger le mode vacances',
        ),
      );
    }
  }

  /// Get all active delegations in the house
  Future<List<VacationDelegation>> getHouseDelegations(String houseId) async {
    try {
      final response = await _dio.get('/api/v1/houses/$houseId/delegations');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => VacationDelegation.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de charger les delegations',
        ),
      );
    }
  }

  /// Get delegations where I am the delegate
  Future<List<VacationDelegation>> getMyDelegations(String houseId) async {
    try {
      final response = await _dio.get('/api/v1/houses/$houseId/my-delegations');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => VacationDelegation.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        formatApiError(
          e,
          fallbackMessage: 'Impossible de charger vos delegations',
        ),
      );
    }
  }
}
