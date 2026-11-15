import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/services/security_visitor_summary_service.dart';
import 'package:security_app/widgets/security_visitor_counters.dart';

Map<String, dynamic> response({String community = 'a', int count = 0}) => {
  'communityId': community,
  'timeZone': 'Asia/Manila',
  'localDate': '2026-11-14',
  'refreshedAt': DateTime.utc(2026, 11, 14).millisecondsSinceEpoch,
  'totalToday': count,
  'activeInside': count,
  'pendingRequests': count,
  'exitsToday': count,
};

SecurityVisitorSummary summary({String community = 'a', int count = 0}) =>
    SecurityVisitorSummary.fromMap(
      response(community: community, count: count),
    );

Widget screen(
  Future<SecurityVisitorSummary> Function() load, {
  String community = 'a',
  int refreshVersion = 0,
}) => MaterialApp(
  home: Scaffold(
    body: SecurityVisitorCounters(
      communityId: community,
      load: load,
      refreshVersion: refreshVersion,
    ),
  ),
);

void main() {
  test(
    'service calls authorized summary without client community parameters',
    () async {
      final service = SecurityVisitorSummaryService(
        invoke: (name, payload) async {
          expect(name, 'getSecurityVisitorSummary');
          expect(payload, isEmpty);
          return response(count: 302);
        },
      );
      final result = await service.load();
      expect(result.communityId, 'a');
      expect(result.totalToday, 302);
      expect(result.timeZone, 'Asia/Manila');
      expect(result.localDate, '2026-11-14');
    },
  );

  for (final invalid in [
    null,
    <String, dynamic>{},
    {...response()}..remove('activeInside'),
    {...response(), 'totalToday': -1},
    {...response(), 'pendingRequests': '0'},
    {...response(), 'refreshedAt': null},
  ]) {
    test('service rejects incomplete or malformed summary: $invalid', () async {
      final service = SecurityVisitorSummaryService(
        invoke: (_, __) async => invalid,
      );
      await expectLater(service.load(), throwsFormatException);
    });
  }

  test('service propagates unavailable callable errors', () async {
    final service = SecurityVisitorSummaryService(
      invoke: (_, __) async => throw StateError('unavailable'),
    );
    await expectLater(service.load(), throwsStateError);
  });

  testWidgets('loading is distinct from genuine zero', (tester) async {
    final pending = Completer<SecurityVisitorSummary>();
    await tester.pumpWidget(screen(() => pending.future));
    expect(find.text('Loading visitor counts…'), findsOneWidget);
    expect(find.text('…'), findsNWidgets(4));
    expect(find.text('0'), findsNothing);
    pending.complete(summary());
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(4));
    expect(find.textContaining('Asia/Manila'), findsOneWidget);
    expect(find.text('Visitor counts unavailable'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('counter values keep their original card mapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        () async => SecurityVisitorSummary.fromMap({
          ...response(),
          'totalToday': 12,
          'activeInside': 3,
          'pendingRequests': 4,
          'exitsToday': 9,
        }),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in {
      'Total': '12',
      'Active': '3',
      'Pending': '4',
      'Exits': '9',
    }.entries) {
      final card = find
          .ancestor(of: find.text(entry.key), matching: find.byType(Column))
          .first;
      expect(
        find.descendant(of: card, matching: find.text(entry.value)),
        findsOneWidget,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failure hides counts and Retry obtains fresh authoritative data',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        screen(() async {
          if (++calls == 1) throw StateError('permission-denied');
          return summary(count: 7);
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Visitor counts unavailable'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(4));
      expect(find.text('0'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNWidgets(4));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'refresh clears stale values while awaiting server and on error',
    (tester) async {
      final refresh = Completer<SecurityVisitorSummary>();
      var calls = 0;
      await tester.pumpWidget(
        screen(
          () => ++calls == 1 ? Future.value(summary(count: 8)) : refresh.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(find.text('8'), findsNothing);
      expect(find.text('Loading visitor counts…'), findsOneWidget);
      refresh.completeError(StateError('unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('8'), findsNothing);
      expect(find.text('Visitor counts unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('community switch discards old in-flight result', (tester) async {
    final old = Completer<SecurityVisitorSummary>();
    await tester.pumpWidget(screen(() => old.future));
    await tester.pumpWidget(
      screen(() async => summary(community: 'b', count: 5), community: 'b'),
    );
    await tester.pumpAndSettle();
    old.complete(summary(count: 99));
    await tester.pumpAndSettle();
    expect(find.text('5'), findsNWidgets(4));
    expect(find.text('99'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wrong-community response never displays counts', (tester) async {
    await tester.pumpWidget(
      screen(() async => summary(community: 'other', count: 99)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Visitor counts unavailable'), findsOneWidget);
    expect(find.text('99'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('returning from visitor operations requests fresh counts', (
    tester,
  ) async {
    var calls = 0;
    Future<SecurityVisitorSummary> load() async => summary(count: ++calls);
    await tester.pumpWidget(screen(load));
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen(load, refreshVersion: 1));
    expect(find.text('1'), findsNothing);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('2'), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timed refresh and app resume reload counters', (tester) async {
    var calls = 0;
    await tester.pumpWidget(screen(() async => summary(count: ++calls)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'timeout reports unavailable and disposed request causes no setState',
    (tester) async {
      final pending = Completer<SecurityVisitorSummary>();
      await tester.pumpWidget(screen(() => pending.future));
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.text('Visitor counts unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(summary(count: 9));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('original cards fit a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen(() async => summary(count: 12)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'dashboard counters use the authorized widget, with no direct visitor read',
    () {
      final source = File(
        'lib/screens/security_dashboard_screen.dart',
      ).readAsStringSync();
      expect(source, contains('return SecurityVisitorCounters('));
      expect(source, isNot(contains(".collection('visitors')")));
    },
  );
}
