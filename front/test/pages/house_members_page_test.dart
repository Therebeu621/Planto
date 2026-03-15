import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/profile_service.dart';
import 'package:planto/features/house/house_members_page.dart';
import '../test_helpers.dart';
import 'page_test_helper.dart';

void main() {
  late MockDioInterceptor mockInterceptor;
  late HouseService houseService;
  late AuthService authService;
  late ProfileService profileService;

  final ownerHouse = House(
    id: 'h1',
    name: 'Ma Maison',
    inviteCode: 'ABC123',
    memberCount: 3,
    roomCount: 2,
    isActive: true,
    role: 'OWNER',
  );

  final guestHouse = House(
    id: 'h1',
    name: 'Ma Maison',
    inviteCode: 'ABC123',
    memberCount: 3,
    roomCount: 2,
    isActive: true,
    role: 'MEMBER',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token':
          // JWT with sub: "user1" (base64 encoded: {"sub":"user1","exp":9999999999})
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyMSIsImV4cCI6OTk5OTk5OTk5OX0.test',
    });
    mockInterceptor = MockDioInterceptor();
    final dio = createMockDio(mockInterceptor);
    houseService = HouseService(dio: dio);
    authService = AuthService(dio: dio);
    profileService = ProfileService(dio: dio);
  });

  void addMembers() {
    mockInterceptor.addMockResponse('/api/v1/houses/h1/members', data: [
      {
        'userId': 'user1',
        'displayName': 'Alice Dupont',
        'email': 'alice@test.com',
        'profilePhotoUrl': null,
        'role': 'OWNER',
        'joinedAt': '2026-01-01T00:00:00',
        'isActive': true,
      },
      {
        'userId': 'user2',
        'displayName': 'Bob Martin',
        'email': 'bob@test.com',
        'profilePhotoUrl': '/photos/bob.jpg',
        'role': 'MEMBER',
        'joinedAt': '2026-02-01T00:00:00',
        'isActive': true,
      },
      {
        'userId': 'user3',
        'displayName': 'Charlie Guest',
        'email': 'charlie@test.com',
        'profilePhotoUrl': null,
        'role': 'GUEST',
        'joinedAt': '2026-03-01T00:00:00',
        'isActive': true,
      },
    ]);
  }

  Widget buildPage({House? house}) {
    return MaterialApp(
      home: HouseMembersPage(
        house: house ?? ownerHouse,
        houseService: houseService,
        authService: authService,
        profileService: profileService,
      ),
    );
  }

  group('HouseMembersPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      FlutterError.onError = origOnError;
    });

    testWidgets('shows appbar with title', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Membres'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows house name and member count in header', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Ma Maison'), findsOneWidget);
      expect(find.text('3 membres'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows member cards with names and emails', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Alice Dupont'), findsOneWidget);
      expect(find.text('alice@test.com'), findsOneWidget);
      expect(find.text('Bob Martin'), findsOneWidget);
      expect(find.text('bob@test.com'), findsOneWidget);
      expect(find.text('Charlie Guest'), findsOneWidget);
      expect(find.text('charlie@test.com'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows role badges', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Proprietaire'), findsOneWidget);
      expect(find.text('Membre'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows "Vous" badge for current user', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Vous'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('shows initials in avatar when no photo', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('AD'), findsOneWidget); // Alice Dupont
      expect(find.text('CG'), findsOneWidget); // Charlie Guest

      FlutterError.onError = origOnError;
    });

    testWidgets('owner can see popup menu for non-self members', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Should find popup menu buttons (for Bob and Charlie, not for current user Alice)
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));

      FlutterError.onError = origOnError;
    });

    testWidgets('non-owner cannot see popup menus', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage(house: guestHouse));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsNothing);

      FlutterError.onError = origOnError;
    });

    testWidgets('popup menu shows role change and remove options', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Tap the first popup menu (for Bob)
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('Changer le role'), findsOneWidget);
      expect(find.text('Exclure'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('change role dialog shows role options', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Changer le role'));
      await tester.pumpAndSettle();

      expect(find.text('Changer le role'), findsWidgets);
      expect(find.textContaining('Role actuel'), findsOneWidget);
      expect(find.text('Proprietaire'), findsWidgets);
      expect(find.text('Membre'), findsWidgets);
      expect(find.text('Invite'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('change role dialog updates role on selection', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Clear and re-add mocks with more specific path first to avoid
      // /api/v1/houses/h1/members matching before /api/v1/houses/h1/members/user2/role
      mockInterceptor.clearResponses();
      mockInterceptor.addMockResponse('/api/v1/houses/h1/members/user2/role',
          data: {
            'userId': 'user2',
            'displayName': 'Bob Martin',
            'email': 'bob@test.com',
            'role': 'GUEST',
            'joinedAt': '2026-02-01T00:00:00',
            'isActive': true,
          });
      addMembers();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Changer le role'));
      await tester.pumpAndSettle();

      // Tap the "Invite" role option (selecting a different role from current)
      final guestOption = find.ancestor(
        of: find.text('Invite'),
        matching: find.byType(InkWell),
      );
      await tester.tap(guestOption.last);
      await tester.pumpAndSettle();

      expect(find.text('Role modifie avec succes'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('remove member shows confirmation dialog', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exclure'));
      await tester.pumpAndSettle();

      expect(find.text('Exclure ce membre ?'), findsOneWidget);
      expect(find.textContaining('Bob Martin'), findsWidgets);
      expect(find.textContaining('code d\'invitation'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('remove member confirmation executes removal', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      mockInterceptor.addMockResponse(
          '/api/v1/houses/h1/members/user2', data: {});

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exclure'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Exclure'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a ete exclu'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('remove member cancel does nothing', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      addMembers();
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exclure'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Members still shown
      expect(find.text('Bob Martin'), findsOneWidget);

      FlutterError.onError = origOnError;
    });

    testWidgets('error loading members shows snackbar', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses/h1/members',
          data: {}, isError: true, errorStatusCode: 500);
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.textContaining('Erreur'), findsWidgets);

      FlutterError.onError = origOnError;
    });

    testWidgets('single member shows singular count', (tester) async {
      setupPageTest(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      final origOnError = suppressOverflowErrors();

      mockInterceptor.addMockResponse('/api/v1/houses/h1/members', data: [
        {
          'userId': 'user1',
          'displayName': 'Alice',
          'email': 'alice@test.com',
          'role': 'OWNER',
          'joinedAt': '2026-01-01T00:00:00',
          'isActive': true,
        },
      ]);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('1 membre'), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });
}
