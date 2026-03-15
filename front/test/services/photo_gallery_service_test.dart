import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planto/core/services/photo_gallery_service.dart';
import '../test_helpers.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late Dio dio;
  late PhotoGalleryService service;

  final photoJson = {
    'id': 'ph1',
    'url': '/uploads/photo.jpg',
    'caption': 'My plant',
    'isPrimary': true,
  };

  setUp(() {
    mockInterceptor = MockDioInterceptor();
    dio = createMockDio(mockInterceptor);
    service = PhotoGalleryService(dio: dio);
  });

  tearDown(() {
    mockInterceptor.clearResponses();
  });

  group('getPhotos', () {
    test('success returns list of photos', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos',
          data: [photoJson]);
      final result = await service.getPhotos('p1');
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, 1);
      expect(result.first['id'], 'ph1');
      expect(result.first['url'], '/uploads/photo.jpg');
    });

    test('error returns empty list', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos',
          isError: true, errorStatusCode: 500);
      final result = await service.getPhotos('p1');
      expect(result, isEmpty);
    });
  });

  group('uploadPhoto', () {
    test('success with caption returns photo data', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos',
          data: photoJson);
      final result = await service.uploadPhoto(
          'p1', [1, 2, 3], 'photo.jpg',
          caption: 'My plant');
      expect(result['id'], 'ph1');
    });

    test('success without caption returns photo data', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos',
          data: photoJson);
      final result =
          await service.uploadPhoto('p1', [1, 2, 3], 'photo.jpg');
      expect(result['id'], 'ph1');
    });
  });

  group('setPrimary', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos/ph1/primary');
      await service.setPrimary('p1', 'ph1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/plants/p1/photos/ph1/primary'));
    });
  });

  group('deletePhoto', () {
    test('success completes', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos/ph1');
      await service.deletePhoto('p1', 'ph1');
      expect(mockInterceptor.capturedRequests.last.path,
          contains('/api/v1/plants/p1/photos/ph1'));
    });
  });

  group('non-200 status branches', () {
    test('getPhotos non-200 returns empty', () async {
      mockInterceptor.addMockResponse('/api/v1/plants/p1/photos',
          data: [], statusCode: 500);
      final result = await service.getPhotos('p1');
      expect(result, isEmpty);
    });
  });
}
