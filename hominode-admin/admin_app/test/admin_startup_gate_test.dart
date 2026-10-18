import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/widgets/admin_startup_gate.dart';

void main() {
  const ready = MaterialApp(home: Text('Authorized app'));
  testWidgets('builds no authorized UI until initialization succeeds', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      AdminStartupGate(initialize: () => pending.future, child: ready),
    );
    expect(find.text('Authorized app'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Authorized app'), findsOneWidget);
  });
  testWidgets('attestation failure stays closed and retry verifies again', (
    tester,
  ) async {
    var calls = 0;
    final retry = Completer<void>();
    await tester.pumpWidget(
      AdminStartupGate(
        initialize: () async {
          if (++calls == 1) throw StateError('sensitive SDK body');
          await retry.future;
        },
        child: ready,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorized app'), findsNothing);
    expect(find.textContaining('sensitive SDK body'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
    expect(calls, 2);
    retry.complete();
    await tester.pumpAndSettle();
    expect(find.text('Authorized app'), findsOneWidget);
  });
  testWidgets('timeout leaves splash and late completion does not authorize', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      AdminStartupGate(
        initialize: () => pending.future,
        timeout: const Duration(seconds: 1),
        child: ready,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Authorized app'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
