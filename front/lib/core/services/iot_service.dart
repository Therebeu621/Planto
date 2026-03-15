import 'package:dio/dio.dart';
import 'package:planto/core/services/api_client.dart';

class IotService {
  late final Dio _dio;
  IotService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<List<Map<String, dynamic>>> getSensorsByHouse(String houseId) async {
    try {
      final response = await _dio.get('/api/v1/iot/house/$houseId/sensors');
      if (response.statusCode == 200) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSensorsByPlant(String plantId) async {
    try {
      final response = await _dio.get('/api/v1/iot/plant/$plantId/sensors');
      if (response.statusCode == 200) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  Future<Map<String, dynamic>> createSensor(String houseId, Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/iot/house/$houseId/sensors', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getReadings(String sensorId, {int limit = 100}) async {
    try {
      final response = await _dio.get(
        '/api/v1/iot/sensors/$sensorId/readings',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  Future<void> deleteSensor(String sensorId) async {
    await _dio.delete('/api/v1/iot/sensors/$sensorId');
  }
}
