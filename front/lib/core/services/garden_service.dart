import 'package:dio/dio.dart';
import 'package:planto/core/services/api_client.dart';

class GardenService {
  late final Dio _dio;
  GardenService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<List<Map<String, dynamic>>> getCultures(String houseId, {String? status}) async {
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      final response = await _dio.get('/api/v1/garden/house/$houseId', queryParameters: params);
      if (response.statusCode == 200) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  Future<Map<String, dynamic>> createCulture(String houseId, Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/garden/house/$houseId', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStatus(String cultureId, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/v1/garden/$cultureId/status', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCulture(String cultureId) async {
    await _dio.delete('/api/v1/garden/$cultureId');
  }
}
