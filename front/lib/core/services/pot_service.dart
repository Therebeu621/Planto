import 'package:dio/dio.dart';
import 'package:planto/core/models/pot_stock.dart';
import 'package:planto/core/models/plant.dart';
import 'package:planto/core/services/api_client.dart';

/// Service for pot stock API operations.
class PotService {
  late final Dio _dio;
  PotService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Get all pot stock for the active house
  Future<List<PotStock>> getPotStock() async {
    try {
      final response = await _dio.get('/api/v1/pots');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PotStock.fromJson(json)).toList();
      }
      throw Exception('Erreur lors du chargement du stock');
    } on DioException catch (e) {
      throw Exception('Erreur reseau: ${e.message}');
    }
  }

  /// Get available pots (quantity > 0)
  Future<List<PotStock>> getAvailablePots() async {
    try {
      final response = await _dio.get('/api/v1/pots/available');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PotStock.fromJson(json)).toList();
      }
      throw Exception('Erreur lors du chargement');
    } on DioException catch (e) {
      throw Exception('Erreur reseau: ${e.message}');
    }
  }

  /// Add pots to stock
  Future<PotStock> addToStock({
    required double diameterCm,
    int quantity = 1,
    String? label,
  }) async {
    try {
      final data = <String, dynamic>{
        'diameterCm': diameterCm,
        'quantity': quantity,
      };
      if (label != null && label.isNotEmpty) data['label'] = label;

      final response = await _dio.post('/api/v1/pots', data: data);
      if (response.statusCode == 201) {
        return PotStock.fromJson(response.data);
      }
      throw Exception('Erreur lors de l\'ajout');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Update pot stock quantity
  Future<PotStock> updateStock(String potId, int quantity) async {
    try {
      final response = await _dio.put(
        '/api/v1/pots/$potId',
        data: {'quantity': quantity},
      );
      if (response.statusCode == 200) {
        return PotStock.fromJson(response.data);
      }
      throw Exception('Erreur lors de la mise a jour');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Delete a pot stock entry
  Future<void> deleteStock(String potId) async {
    try {
      await _dio.delete('/api/v1/pots/$potId');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Repot a plant (takes new pot from stock, returns old pot)
  Future<Plant> repotPlant(String plantId, double newDiameterCm, {String? notes}) async {
    try {
      final data = <String, dynamic>{
        'newDiameterCm': newDiameterCm,
      };
      if (notes != null && notes.isNotEmpty) data['notes'] = notes;

      final response = await _dio.post(
        '/api/v1/pots/repot/$plantId',
        data: data,
      );
      if (response.statusCode == 200) {
        return Plant.fromJson(response.data);
      }
      throw Exception('Erreur lors du rempotage');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Pot non disponible en stock');
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Get suggested pots for repotting a plant
  Future<List<PotStock>> getSuggestedPots(String plantId) async {
    try {
      final response = await _dio.get('/api/v1/pots/suggestions/$plantId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PotStock.fromJson(json)).toList();
      }
      throw Exception('Erreur lors du chargement');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }
}
