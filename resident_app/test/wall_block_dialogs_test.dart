import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/community_wall_screen.dart';
import 'package:resident_app/src/modals/post_menu_bottomsheet.dart';
import 'package:resident_app/src/models/post.dart';
import 'package:resident_app/src/providers/theme_provider.dart';
import 'package:resident_app/src/services/post_firestore_service.dart';
import 'package:resident_app/src/widgets/wall_block_dialogs.dart';

class _Service extends Fake implements PostFirestoreService {
  int feedCalls = 0, listCalls = 0, changes = 0;
  bool blocked = false;
  Object? listError, changeError;
  Completer<List<Map<String, dynamic>>>? pendingList;
  Completer<void>? pendingChange;
  List<Map<String, dynamic>> users = [
    {'userId': 'other', 'name': 'Other Resident', 'flatLabel': 'N014'},
  ];
  @override
  Stream<void> moderationChanges() => const Stream.empty();
  @override
  Future<List<Post>> getAllPosts() async {
    feedCalls++;
    return blocked
        ? []
        : [
            Post(
              id: 'post',
              authorId: 'other',
              authorName: 'Other Resident',
              profileImage: '',
              flat: 'N014',
              timeAgo: 'Now',
              content: 'A visible community post',
              likes: 0,
              comments: 0,
            ),
          ];
  }

  @override
  Future<List<Map<String, dynamic>>> blockedUsers() async {
    listCalls++;
    if (listError != null) throw listError!;
    if (pendingList != null) return pendingList!.future;
    return users.map((user) => Map<String, dynamic>.from(user)).toList();
  }

  @override
  Future<void> setUserBlocked(String uid, bool value) async {
    changes++;
    if (changeError != null) throw changeError!;
    if (pendingChange != null) await pendingChange!.future;
    blocked = value;
    if (!value) users.removeWhere((user) => user['userId'] == uid);
  }
}

void main() {
  Future<void> openWall(WidgetTester tester, _Service service) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: CommunityWallScreen(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<VoidCallback> block(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    final duplicate = tester
        .widget<PostMenuBottomSheet>(find.byType(PostMenuBottomSheet))
        .onBlock;
    await tester.tap(find.text('Block User'));
    await tester.pump();
    return duplicate;
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Blocked users'));
    await tester.pump();
  }

  test(
    'block and unblock require explicit backend confirmation and preserve the existing callable schema',
    () async {
      final payloads = <Map<String, dynamic>>[];
      final service = PostFirestoreService(
        moderationCall: (name, data) async {
          expect(name, 'setWallUserBlock');
          payloads.add(data);
          return {'success': true};
        },
      );
      await service.setUserBlocked('other', true);
      await service.setUserBlocked('other', false);
      expect(payloads, [
        {'userId': 'other', 'blocked': true},
        {'userId': 'other', 'blocked': false},
      ]);
      for (final result in [
        <String, dynamic>{},
        {'success': false},
      ]) {
        final unconfirmed = PostFirestoreService(
          moderationCall: (_, _) async => result,
        );
        await expectLater(
          unconfirmed.setUserBlocked('other', true),
          throwsStateError,
        );
      }
    },
  );

  test(
    'blocked-list request relies on current authenticated community scope without accepting arbitrary IDs',
    () async {
      var active = 'A';
      final service = PostFirestoreService(
        moderationCall: (name, data) async {
          expect(name, 'listWallUserBlocks');
          expect(data, isEmpty);
          return {
            'users': [
              {
                'userId': 'resident-$active',
                'name': 'Community $active Resident',
              },
            ],
          };
        },
      );
      expect((await service.blockedUsers()).single['userId'], 'resident-A');
      active = 'B';
      expect((await service.blockedUsers()).single['userId'], 'resident-B');
    },
  );

  testWidgets(
    'Block shows progress, suppresses duplicate taps and confirms success before refreshing the Wall',
    (tester) async {
      final service = _Service()..pendingChange = Completer<void>();
      await openWall(tester, service);
      final duplicate = await block(tester);
      duplicate();
      await tester.pump();
      expect(service.changes, 1);
      expect(find.text('Blocking resident...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Resident blocked.'), findsNothing);
      service.pendingChange!.complete();
      await tester.pumpAndSettle();
      expect(service.changes, 1);
      expect(find.text('Resident blocked.'), findsOneWidget);
      expect(find.text('No posts to show right now.'), findsOneWidget);
      expect(find.textContaining('Be the first'), findsNothing);
      expect(service.feedCalls, 2);
    },
  );

  testWidgets(
    'Block exposes meaningful errors and Retry succeeds only after confirmation',
    (tester) async {
      final service = _Service()
        ..changeError = FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Resident access is unavailable.',
        );
      await openWall(tester, service);
      await block(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Resident access is unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Resident blocked.'), findsNothing);
      expect(service.feedCalls, 1);
      service.changeError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(service.changes, 2);
      expect(find.text('Resident blocked.'), findsOneWidget);
    },
  );

  testWidgets(
    'Blocked list opens immediately with loading then compact names, optional units and count',
    (tester) async {
      final service = _Service()
        ..pendingList = Completer<List<Map<String, dynamic>>>();
      await openWall(tester, service);
      await openList(tester);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Blocked residents'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('0 blocked residents'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Blocked users',
              ),
            )
            .onPressed,
        isNull,
      );
      service.pendingList!.complete(service.users);
      await tester.pumpAndSettle();
      expect(find.text('1 blocked resident'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'N014'), findsOneWidget);
      expect(find.text('Unblock'), findsOneWidget);
    },
  );

  testWidgets(
    'List fetch failure stays distinct from empty and supports Retry',
    (tester) async {
      final service = _Service()
        ..listError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Offline',
        );
      await openWall(tester, service);
      await openList(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('haven’t blocked'), findsNothing);
      service.listError = null;
      await tester.tap(find.text('Retry list'));
      await tester.pumpAndSettle();
      expect(service.listCalls, 2);
      expect(find.text('Unblock'), findsOneWidget);
    },
  );

  testWidgets(
    'Unblock shows per-row progress, prevents duplicates and refreshes list and Wall',
    (tester) async {
      final service = _Service()
        ..blocked = true
        ..pendingChange = Completer<void>();
      await openWall(tester, service);
      await openList(tester);
      await tester.pumpAndSettle();
      final button = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Unblock'))
          .onPressed!;
      button();
      button();
      await tester.pump();
      expect(service.changes, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Resident unblocked.'), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
            .onPressed,
        isNull,
      );
      service.pendingChange!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Resident unblocked.'), findsOneWidget);
      expect(find.text('0 blocked residents'), findsOneWidget);
      expect(find.text('You haven’t blocked any residents.'), findsOneWidget);
      expect(service.listCalls, 2);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(service.feedCalls, 2);
      expect(find.text('A visible community post'), findsOneWidget);
    },
  );

  testWidgets(
    'Unblock failure retains the row and allows retry without a false success',
    (tester) async {
      final service = _Service()
        ..changeError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Temporary network failure',
        );
      await openWall(tester, service);
      await openList(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unable to unblock resident.'),
        findsOneWidget,
      );
      expect(find.text('1 blocked resident'), findsOneWidget);
      expect(find.text('Resident unblocked.'), findsNothing);
      service.changeError = null;
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      expect(service.changes, 2);
      expect(find.text('Resident unblocked.'), findsOneWidget);
    },
  );

  testWidgets('Empty list has an accurate count and empty state', (
    tester,
  ) async {
    final service = _Service()..users = [];
    await openWall(tester, service);
    await openList(tester);
    await tester.pumpAndSettle();
    expect(find.text('0 blocked residents'), findsOneWidget);
    expect(find.text('You haven’t blocked any residents.'), findsOneWidget);
    expect(find.text('Unblock'), findsNothing);
  });

  testWidgets(
    'Large list scrolls and searches names or units locally without extra fetches',
    (tester) async {
      final service = _Service()
        ..users = List.generate(
          100,
          (i) => {
            'userId': 'r-$i',
            'name': 'Resident ${i.toString().padLeft(3, '0')}',
            'unitLabel': 'U${i + 1}',
          },
        );
      await openWall(tester, service);
      await openList(tester);
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.descendant(
          of: find.byType(BlockedResidentsDialog),
          matching: find.byType(ListView),
        ),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Resident 099'),
        200,
        scrollable: scroll,
      );
      expect(find.text('Resident 099'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'resident 050');
      await tester.pumpAndSettle();
      expect(find.text('Resident 050'), findsOneWidget);
      expect(find.text('100 blocked residents'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'u100');
      await tester.pumpAndSettle();
      expect(find.text('Resident 099'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no matching resident');
      await tester.pumpAndSettle();
      expect(find.text('No matching residents.'), findsOneWidget);
      expect(service.listCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Closing while list loads safely ignores the late response', (
    tester,
  ) async {
    final service = _Service()
      ..pendingList = Completer<List<Map<String, dynamic>>>();
    await openWall(tester, service);
    await openList(tester);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    service.pendingList!.complete(service.users);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Blocked residents'), findsNothing);
  });
}
