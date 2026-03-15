import 'package:dio/dio.dart';
import 'package:planto/core/services/api_client.dart';

class StatsService {
  late final Dio _dio;
  StatsService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _dio.get('/api/v1/stats/dashboard');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getAnnualStats({int? year}) async {
    try {
      final params = <String, dynamic>{};
      if (year != null) params['year'] = year;
      final response = await _dio.get('/api/v1/stats/annual', queryParameters: params);
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }
}
