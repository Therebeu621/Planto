import 'package:dio/dio.dart';
import 'package:planto/core/services/api_client.dart';

/// Plant search result from local JSON database
class PlantResult {
  final String nomFrancais;
  final String nomLatin;
  final int arrosageFrequenceJours;
  final String luminosite;

  PlantResult({
    required this.nomFrancais,
    required this.nomLatin,
    required this.arrosageFrequenceJours,
    required this.luminosite,
  });

  factory PlantResult.fromJson(Map<String, dynamic> json) {
    return PlantResult(
      nomFrancais: json['nomFrancais'] ?? '',
      nomLatin: json['nomLatin'] ?? '',
      arrosageFrequenceJours: json['arrosageFrequenceJours'] ?? 7,
      luminosite: json['luminosite'] ?? 'Mi-ombre',
    );
  }

  /// Get exposure enum value from luminosite
  String getExposureValue() {
    switch (luminosite) {
      case 'Plein soleil':
        return 'SUN';
      case 'Ombre':
        return 'SHADE';
      default:
        return 'PARTIAL_SHADE';
    }
  }

  /// Get display name
  String get displayName => nomFrancais;

  /// Get description
  String get description => nomLatin;
}

/// Service for plant search API operations.
/// Uses ApiClient with automatic token refresh.
class SpeciesService {
  late final Dio _dio;
  SpeciesService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Search plants by name (French or Latin)
  /// Returns list of matching plants with care info
  Future<List<PlantResult>> searchPlants(String query) async {
    if (query.length < 2) return [];

    try {
      final response = await _dio.get(
        '/api/v1/species/search',
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PlantResult.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException {
      return [];
    }
  }

  /// Get plant by exact name
  Future<PlantResult?> getPlantByName(String name) async {
    if (name.isEmpty) return null;

    try {
      final response = await _dio.get(
        '/api/v1/species/by-name',
        queryParameters: {'name': name},
      );

      if (response.statusCode == 200) {
        return PlantResult.fromJson(response.data);
      } else {
        return null;
      }
    } on DioException {
      return null;
    }
  }

  /// Get database status
  Future<Map<String, dynamic>> getDatabaseStatus() async {
    try {
      final response = await _dio.get('/api/v1/species/status');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'status': 'error', 'plantCount': 0};
      }
    } on DioException {
      return {'status': 'error', 'plantCount': 0};
    }
  }
}
