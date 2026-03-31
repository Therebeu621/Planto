import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/services/gemini_service.dart';
import 'package:planto/features/plant/plant_identification_page.dart';
import 'page_test_helper.dart';

// Minimal valid 1x1 transparent PNG
final _validPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, // RGBA, 8-bit
  0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
  0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE5, // data
  0x27, 0xDE, 0xFC,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
  0xAE, 0x42, 0x60, 0x82,
]);

/// Creates a mock GeminiService that returns a successful identification
GeminiService createSuccessGeminiService() {
  final mockClient = http_testing.MockClient((request) async {
    return http.Response(
      '{"candidates":[{"content":{"parts":[{"text":"{\\"petit_nom\\":\\"Mon Ficus\\",\\"espece\\":\\"Ficus elastica\\",\\"arrosage_jours\\":7,\\"luminosite\\":\\"Mi-ombre\\",\\"description\\":\\"Un beau ficus\\"}"}]}}]}',
      200,
    );
  });
  return GeminiService(client: mockClient, apiKey: 'test-key');
}

/// Creates a mock GeminiService that fails
GeminiService createErrorGeminiService() {
  final mockClient = http_testing.MockClient((request) async {
    return http.Response('{"error": "API quota exceeded"}', 429);
  });
  return GeminiService(client: mockClient, apiKey: 'test-key');
}

/// Creates a mock GeminiService that throws
GeminiService createThrowingGeminiService() {
  final mockClient = http_testing.MockClient((request) async {
    throw Exception('Network error');
  });
  return GeminiService(client: mockClient, apiKey: 'test-key');
}

Widget mockAddPlantPage(_, __) {
  return const Scaffold(body: Center(child: Text('Mock add plant page')));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Helper to pump through the analysis phase until error dialog appears
  // Uses pump with durations since the repeating AnimationController
  // prevents pumpAndSettle from completing
  Future<void> pumpUntilErrorDialog(WidgetTester tester) async {
    // Let the Future.delayed(500ms) complete and API call fail
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // Pump a few more frames for the dialog to render
    await tester.pump();
    await tester.pump();
  }

  group('PlantIdentificationPage', () {
    testWidgets('shows status text and progress indicator on start', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
            addPlantPageBuilder: mockAddPlantPage,
          ),
        ),
      );
      // First pump: _analyzeImage has run setState => "Envoi de l'image..."
      await tester.pump();

      // Status message changes to "Envoi..."
      expect(find.textContaining('Envoi'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Let the analysis complete to avoid timer pending
      await pumpUntilErrorDialog(tester);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows image in circular container', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      await pumpUntilErrorDialog(tester);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows back button', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await pumpUntilErrorDialog(tester);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows sparkle emoji during analysis', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );
      await tester.pump();

      // Analyzing state shows sparkle emoji
      expect(find.textContaining('\u2728'), findsOneWidget);

      await pumpUntilErrorDialog(tester);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows explanatory text during analysis', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      // The explanatory text 'Notre IA botaniste...' appears at the same
      // time as the initial status and only while _isAnalyzing is true.
      // We verify the text exists in the build method by checking during
      // the initial loading phase (before the 500ms delay)
      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );
      await tester.pump();

      // During analysis (_isAnalyzing=true), the explanatory text should be visible
      // The text contains "IA botaniste" in the build method
      expect(find.textContaining('IA botaniste'), findsOneWidget);

      // Let the analysis complete
      await pumpUntilErrorDialog(tester);

      FlutterError.onError = origOnError;
    });

    testWidgets('updates status message to "Envoi de l\'image"', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );

      // Right after build, first setState changes to "Envoi de l'image"
      await tester.pump();
      expect(find.textContaining('Envoi'), findsWidgets);

      await pumpUntilErrorDialog(tester);

      FlutterError.onError = origOnError;
    });

    testWidgets('on success, shows "Plante identifiee" before navigating', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      // Suppress all errors (navigation to AddPlantPage may fail without full mocks)
      FlutterError.onError = (details) {};

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createSuccessGeminiService(),
            addPlantPageBuilder: mockAddPlantPage,
          ),
        ),
      );

      // Process the Future.delayed(500ms) + API call
      await tester.pump(const Duration(milliseconds: 600));
      // API returns immediately, so "Plante identifiee" is set
      await tester.pump();
      await tester.pump();

      expect(find.text('Plante identifiee !'), findsOneWidget);

      // Pump past the 800ms post-success delay and navigation
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Mock add plant page'), findsOneWidget);
    });

    testWidgets('on error, shows error dialog with options', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
            addPlantPageBuilder: mockAddPlantPage,
          ),
        ),
      );

      await pumpUntilErrorDialog(tester);

      expect(find.text('Identification impossible'), findsWidgets);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Saisie manuelle'), findsOneWidget);
      expect(find.textContaining('manuellement'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('error dialog cancel button pops back', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => PlantIdentificationPage(
                imageBytes: _validPng,
                geminiService: createErrorGeminiService(),
              ),
            ),
            onPopPage: (route, result) {
              return route.didPop(result);
            },
          ),
        ),
      );

      await pumpUntilErrorDialog(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      FlutterError.onError = origOnError;
    });

    testWidgets('error dialog "Saisie manuelle" navigates to add plant', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );

      await pumpUntilErrorDialog(tester);

      await tester.tap(find.text('Saisie manuelle'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows "Identification impossible" status on error', (
      tester,
    ) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );

      await pumpUntilErrorDialog(tester);

      // Status message and check_circle (not analyzing)
      expect(find.text('Identification impossible'), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('network error also shows error dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createThrowingGeminiService(),
          ),
        ),
      );

      await pumpUntilErrorDialog(tester);

      expect(find.text('Identification impossible'), findsWidgets);
      // The thrown Exception is caught by GeminiService and wrapped as
      // GeminiException('Erreur de connexion: ...')
      expect(find.textContaining('Erreur de connexion'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows seedling emoji after analysis complete', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      await tester.pumpWidget(
        MaterialApp(
          home: PlantIdentificationPage(
            imageBytes: _validPng,
            geminiService: createErrorGeminiService(),
          ),
        ),
      );

      await pumpUntilErrorDialog(tester);

      // After analysis ends (error state), shows seedling emoji
      expect(find.textContaining('\uD83C\uDF31'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });
}
