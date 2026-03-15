import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/widgets/plant_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  PlantSummary createPlant({
    String id = '1',
    String nickname = 'My Fern',
    bool needsWatering = false,
    DateTime? nextWateringDate,
    String? photoUrl,
    bool isSick = false,
    bool isWilted = false,
    bool needsRepotting = false,
  }) {
    return PlantSummary(
      id: id,
      nickname: nickname,
      needsWatering: needsWatering,
      nextWateringDate: nextWateringDate,
      photoUrl: photoUrl,
      isSick: isSick,
      isWilted: isWilted,
      needsRepotting: needsRepotting,
    );
  }

  group('PlantCard', () {
    testWidgets('renders plant nickname', (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(nickname: 'Ficus'),
          onWater: () {},
          onTap: () {},
        ),
      ));

      expect(find.text('Ficus'), findsOneWidget);
    });

    testWidgets('tapping the card calls onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(),
          onWater: () {},
          onTap: () => tapped = true,
        ),
      ));

      // Tap on the plant nickname area (GestureDetector)
      await tester.tap(find.text('My Fern'));
      expect(tapped, isTrue);
    });

    testWidgets('water button calls onWater', (tester) async {
      bool watered = false;
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(),
          onWater: () => watered = true,
          onTap: () {},
        ),
      ));

      // Tap the water drop icon button
      await tester.tap(find.byIcon(Icons.water_drop_outlined));
      expect(watered, isTrue);
    });

    testWidgets('shows urgent badge when needsWatering is true and no nextWateringDate',
        (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(needsWatering: true),
          onWater: () {},
          onTap: () {},
        ),
      ));

      expect(find.textContaining('\u00C0 arroser'), findsOneWidget);
    });

    testWidgets('shows urgent badge when nextWateringDate is in the past',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(
            needsWatering: true,
            nextWateringDate: pastDate,
          ),
          onWater: () {},
          onTap: () {},
        ),
      ));

      expect(find.textContaining('\u00C0 arroser'), findsOneWidget);
    });

    testWidgets('shows urgent badge when nextWateringDate is today',
        (tester) async {
      final today = DateTime.now();
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(
            needsWatering: false,
            nextWateringDate: today,
          ),
          onWater: () {},
          onTap: () {},
        ),
      ));

      expect(find.textContaining('\u00C0 arroser'), findsOneWidget);
    });

    testWidgets('shows J-X badge when nextWateringDate is in the future',
        (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 5));
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(
            needsWatering: false,
            nextWateringDate: futureDate,
          ),
          onWater: () {},
          onTap: () {},
        ),
      ));

      // daysUntilWatering should be around 5 (could be 4 depending on time)
      expect(find.textContaining('J-'), findsOneWidget);
    });

    testWidgets('shows no badge when not urgent and no nextWateringDate',
        (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(needsWatering: false),
          onWater: () {},
          onTap: () {},
        ),
      ));

      // No badge should be shown
      expect(find.textContaining('\u00C0 arroser'), findsNothing);
      expect(find.textContaining('J-'), findsNothing);
    });

    testWidgets('shows placeholder when no photo URL', (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(photoUrl: null),
          onWater: () {},
          onTap: () {},
        ),
      ));

      // Placeholder uses Icons.local_florist
      expect(find.byIcon(Icons.local_florist), findsOneWidget);
    });

    testWidgets('shows placeholder when photoUrl is empty string',
        (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(photoUrl: ''),
          onWater: () {},
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.local_florist), findsOneWidget);
    });

    testWidgets('renders with photo URL and shows image network',
        (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(photoUrl: 'https://example.com/photo.jpg'),
          onWater: () {},
          onTap: () {},
        ),
      ));

      // Image.network should be present
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders Card widget', (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(),
          onWater: () {},
          onTap: () {},
        ),
      ));

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('water button icon is water_drop_outlined', (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(),
          onWater: () {},
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('urgent plant water button uses orange colors',
        (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(needsWatering: true),
          onWater: () {},
          onTap: () {},
        ),
      ));

      // The water icon should use orange color for urgent plants
      final icon = tester.widget<Icon>(find.byIcon(Icons.water_drop_outlined));
      expect(icon.color, Colors.orange.shade700);
    });

    testWidgets('non-urgent plant water button uses primary color',
        (tester) async {
      await tester.pumpWidget(buildApp(
        PlantCard(
          plant: createPlant(needsWatering: false),
          onWater: () {},
          onTap: () {},
        ),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.water_drop_outlined));
      expect(icon.color, const Color(0xFF4A6741)); // AppTheme.primaryColor
    });
  });
}
