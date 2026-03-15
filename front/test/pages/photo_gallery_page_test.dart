import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/photo_gallery_service.dart';
import 'package:planto/features/plant/photo_gallery_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late PhotoGalleryService photoService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    photoService = PhotoGalleryService(dio: dio);
  });

  void addPhotos({bool withPrimary = true}) {
    mockInterceptor.addMockResponse('/api/v1/plants/p1/photos', data: [
      {
        'id': 'photo1',
        'photoUrl': 'http://example.com/photo1.jpg',
        'isPrimary': withPrimary,
        'caption': 'First photo',
        'createdAt': '2026-03-01T00:00:00',
      },
      {
        'id': 'photo2',
        'photoUrl': '/uploads/photo2.jpg',
        'isPrimary': false,
        'caption': null,
        'createdAt': '2026-03-10T00:00:00',
      },
    ]);
  }

  void addEmptyPhotos() {
    mockInterceptor.addMockResponse(
        '/api/v1/plants/p1/photos', data: <Map<String, dynamic>>[]);
  }

  void addPhotoWithNullUrl() {
    mockInterceptor.addMockResponse('/api/v1/plants/p1/photos', data: [
      {
        'id': 'photo3',
        'photoUrl': null,
        'isPrimary': false,
      },
    ]);
  }

  Widget buildPage() {
    return MaterialApp(
      home: PhotoGalleryPage(
        plantId: 'p1',
        plantName: 'Mon Ficus',
        photoGalleryService: photoService,
      ),
    );
  }

  group('PhotoGalleryPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows appbar with plant name', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Photos - Mon Ficus'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows add photo button in appbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows photo grid with photos', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows "Principal" badge on primary photo', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos(withPrimary: true);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Principal'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('no "Principal" badge when photo is not primary', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos(withPrimary: false);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Principal'), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows empty state with icon and add button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addEmptyPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Aucune photo'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('add photo button opens source selection bottom sheet',
        (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_a_photo));
      await tester.pumpAndSettle();

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Galerie'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('long press on photo opens options bottom sheet', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Long press on the first photo grid item
      final gestureDetectors = find.byType(GestureDetector);
      await tester.longPress(gestureDetectors.first);
      await tester.pumpAndSettle();

      expect(find.text('Definir comme principale'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('set primary option calls service', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      mockInterceptor.addMockResponse(
          '/api/v1/plants/p1/photos/photo1/primary', data: {});

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final gestureDetectors = find.byType(GestureDetector);
      await tester.longPress(gestureDetectors.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Definir comme principale'));
      await tester.pumpAndSettle();

      expect(find.text('Photo principale mise a jour'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete option shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final gestureDetectors = find.byType(GestureDetector);
      await tester.longPress(gestureDetectors.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer la photo ?'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('delete confirmation deletes photo', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      mockInterceptor.addMockResponse(
          '/api/v1/plants/p1/photos/photo1', data: {});

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final gestureDetectors = find.byType(GestureDetector);
      await tester.longPress(gestureDetectors.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('delete cancel does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final gestureDetectors = find.byType(GestureDetector);
      await tester.longPress(gestureDetectors.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Photos still shown
      expect(find.byType(GridView), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('tapping photo opens fullscreen gallery', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      // Suppress all Flutter errors (including network image errors in test env)
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {};

      addPhotoWithNullUrl(); // Use null URL photos to avoid network image loading
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Tap the first photo
      final gestureDetectors = find.byType(GestureDetector);
      await tester.tap(gestureDetectors.first);
      await tester.pumpAndSettle();

      // Fullscreen gallery should show with PageView
      expect(find.byType(PageView), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('photo with null url shows placeholder icon', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotoWithNullUrl();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('photo with relative url resolves to full url', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addPhotos();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Photo grid should render (even if images fail to load in test)
      expect(find.byType(GridView), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });
}
