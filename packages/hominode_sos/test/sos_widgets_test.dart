import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_sos/hominode_sos.dart';

import 'sos_test_client.dart';

void main() {
  Future<void> resident(
    WidgetTester tester,
    TestSosClient client, {
    SosLocationCapture? capture,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResidentSosPage(client: client, captureLocation: capture),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.text('Request SOS'));
    await tester.pump();
    await tester.tap(find.text('Request SOS — 1/3'));
    await tester.pump();
    await tester.tap(find.text('Request SOS — 2/3'));
    await tester.pumpAndSettle();
  }

  testWidgets('exactly three taps trigger once, with no activation questions', (
    tester,
  ) async {
    final client = TestSosClient();
    addTearDown(client.dispose);
    var captures = 0;
    await resident(
      tester,
      client,
      capture: () async {
        captures++;
        return null;
      },
    );
    final semantics = tester.ensureSemantics();
    expect(find.byType(CheckboxListTile), findsNothing);
    for (var tap = 1; tap <= 2; tap++) {
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Request SOS — $tap/3'), findsOneWidget);
      expect(find.bySemanticsLabel('Request SOS — $tap/3'), findsOneWidget);
      expect(client.triggers, 0);
      expect(captures, 0);
      expect(find.byType(AlertDialog), findsNothing);
    }
    // Extra rapid taps before the next frame must not duplicate the request.
    await tester.tap(find.byType(FilledButton));
    expect(client.triggers, 1);
    expect(captures, 1);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(client.triggers, 1);
    expect(captures, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Request SOS'), findsNothing);
    expect(find.text('CANCEL SOS'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'entry opens activation, server confirmation opens current emergency',
    (tester) async {
      final client = TestSosClient();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: SosEntryButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ResidentSosPage(client: client),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SOS — Emergency assistance'));
      await tester.pumpAndSettle();
      await send(tester);
      expect(client.triggers, 1);
      expect(find.text('Waiting for acknowledgement'), findsOneWidget);
      expect(find.textContaining('received by the server'), findsOneWidget);
    },
  );
  testWidgets(
    'submitting disables duplicate trigger and never displays premature success',
    (tester) async {
      final client = TestSosClient()..triggerWait = Completer<void>();
      addTearDown(client.dispose);
      await resident(tester, client);
      await send(tester);
      expect(
        find.textContaining('awaiting server confirmation'),
        findsOneWidget,
      );
      expect(find.textContaining('received by the server'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      expect(client.triggers, 1);
      client.triggerWait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Waiting for acknowledgement'), findsOneWidget);
    },
  );
  testWidgets(
    'network failure is prominent; retry reuses request ID and succeeds',
    (tester) async {
      final client = TestSosClient()
        ..triggerError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'raw internals',
        );
      addTearDown(client.dispose);
      await resident(tester, client);
      await send(tester);
      expect(find.textContaining('Unable to confirm'), findsOneWidget);
      expect(find.textContaining('received by the server'), findsNothing);
      expect(find.textContaining('raw internals'), findsNothing);
      client.triggerError = null;
      await tester.tap(find.text('Retry SOS'));
      await tester.pumpAndSettle();
      expect(client.requestIds.toSet().length, 1);
      expect(find.text('Waiting for acknowledgement'), findsOneWidget);
    },
  );
  testWidgets('location failure does not prevent sending', (tester) async {
    final client = TestSosClient();
    addTearDown(client.dispose);
    await resident(
      tester,
      client,
      capture: () async => throw StateError('Permission denied'),
    );
    await send(tester);
    expect(client.lastLocation, isNull);
    expect(client.triggers, 1);
    expect(find.text('Waiting for acknowledgement'), findsOneWidget);
  });
  testWidgets('available one-time location is sent', (tester) async {
    final client = TestSosClient();
    addTearDown(client.dispose);
    final location = <String, dynamic>{
      'latitude': 14.5,
      'longitude': 121.0,
      'accuracy': 100.0,
      'capturedAt': 1700000000000,
    };
    await resident(tester, client, capture: () async => location);
    await send(tester);
    expect(client.triggers, 1);
    expect(client.lastLocation, location);
  });
  testWidgets('location times out after two seconds; late fix cannot resend', (
    tester,
  ) async {
    final client = TestSosClient();
    addTearDown(client.dispose);
    final location = Completer<Map<String, dynamic>?>();
    await resident(tester, client, capture: () => location.future);
    await send(tester);
    expect(client.triggers, 0);
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(client.triggers, 1);
    expect(client.lastLocation, isNull);
    expect(find.text('CANCEL SOS'), findsOneWidget);
    location.complete({'latitude': 14.5, 'longitude': 121.0});
    await tester.pumpAndSettle();
    expect(client.triggers, 1);
    expect(client.lastLocation, isNull);
  });
  testWidgets('existing active SOS opens directly without another trigger', (
    tester,
  ) async {
    final client = TestSosClient()..activeAlertId = 'alert';
    client.emit('responding');
    addTearDown(client.dispose);
    await resident(tester, client);
    expect(find.text('Security responding'), findsOneWidget);
    expect(client.triggers, 0);
  });
  testWidgets(
    'resident follows live acknowledgement/responding/resolution; cancel only while triggered',
    (tester) async {
      final client = TestSosClient()..activeAlertId = 'alert';
      client.emit('triggered');
      addTearDown(client.dispose);
      await resident(tester, client);
      expect(find.text('CANCEL SOS'), findsOneWidget);
      for (final entry in {
        'acknowledged': 'Acknowledged',
        'responding': 'Security responding',
        'resolved': 'Resolved',
        'cancelled': 'Cancelled',
        'unknown': 'Status unavailable',
      }.entries) {
        client.emit(entry.key);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('CANCEL SOS'), findsNothing);
      }
      expect(find.text('Acknowledge SOS'), findsNothing);
    },
  );
  testWidgets('resident cancellation uses existing transition once', (
    tester,
  ) async {
    final client = TestSosClient()..actionWait = Completer<void>();
    addTearDown(client.dispose);
    await resident(tester, client);
    await send(tester);
    await tester.tap(find.text('CANCEL SOS'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(client.actions, 1);
    client.actionWait!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('CANCEL SOS'), findsNothing);
  });
  testWidgets(
    'security sees custom unit and controls the lifecycle with duplicate actions disabled',
    (tester) async {
      final client = TestSosClient()..actionWait = Completer<void>();
      client.emit('triggered');
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SosDetailPage(
            client: client,
            communityId: 'community',
            alertId: 'alert',
            responder: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Villa Cluster / Villa-03'), findsOneWidget);
      await tester.tap(find.text('Acknowledge SOS'));
      await tester.pumpAndSettle();
      expect(client.actions, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      client.actionWait!.complete();
      client.actionWait = null;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark responding'));
      await tester.pumpAndSettle();
      expect(find.text('Security responding'), findsOneWidget);
      await tester.tap(find.text('Resolve SOS'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Help provided');
      await tester.tap(find.text('Confirm resolution'));
      await tester.pumpAndSettle();
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Resolve SOS'), findsNothing);
    },
  );
  testWidgets(
    'admin banner count and list update live, scoped to selected community',
    (tester) async {
      final client = TestSosClient();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosActiveBanner(client: client, communityId: 'community'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 active SOS alerts'), findsOneWidget);
      client.alerts = [client.alert('triggered')];
      client.lists.add(client.alerts);
      await tester.pumpAndSettle();
      expect(find.text('1 active SOS alerts'), findsOneWidget);
      await tester.tap(find.text('1 active SOS alerts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Villa Cluster / Villa-03'), findsOneWidget);
      expect(client.watchedCommunities.every((v) => v == 'community'), isTrue);
      client.lists.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No active SOS alerts'), findsOneWidget);
    },
  );
  testWidgets('state is announced accessibly and does not rely on color', (
    tester,
  ) async {
    final client = TestSosClient();
    client.emit('responding');
    addTearDown(client.dispose);

    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: SosDetailPage(
          client: client,
          communityId: 'community',
          alertId: 'alert',
          responder: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Security responding'), findsOneWidget);

    semantics.dispose();
  });
  test(
    'only trusted SOS notification documents produce valid detail destinations',
    () {
      expect(
        sosAlertIdFromNotification({
          'type': 'sos',
          'sourceEntityId': 'canonical-alert',
        }),
        'canonical-alert',
      );
      expect(
        sosAlertIdFromNotification({
          'type': 'general',
          'sourceEntityId': 'canonical-alert',
        }),
        isNull,
      );
      expect(
        sosAlertIdFromNotification({
          'type': 'sos',
          'sourceEntityId': '../other',
        }),
        isNull,
      );
    },
  );
}
