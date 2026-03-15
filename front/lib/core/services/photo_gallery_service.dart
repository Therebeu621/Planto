import 'package:dio/dio.dart';
import 'package:planto/core/services/api_client.dart';

class PhotoGalleryService {
  late final Dio _dio;
  PhotoGalleryService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<List<Map<String, dynamic>>> getPhotos(String plantId) async {
    try {
      final response = await _dio.get('/api/v1/plants/$plantId/photos');
      if (response.statusCode == 200) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  Future<Map<String, dynamic>> uploadPhoto(String plantId, List<int> bytes, String fileName, {String? caption}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (caption != null) 'caption': caption,
    });
    final response = await _dio.post('/api/v1/plants/$plantId/photos', data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<void> setPrimary(String plantId, String photoId) async {
    await _dio.put('/api/v1/plants/$plantId/photos/$photoId/primary');
  }

  Future<void> deletePhoto(String plantId, String photoId) async {
    await _dio.delete('/api/v1/plants/$plantId/photos/$photoId');
  }
}
