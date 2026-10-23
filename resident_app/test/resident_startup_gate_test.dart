import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_startup_gate.dart';

void main() {
  testWidgets('transient startup failure recovers without manual retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ResidentStartupGate(
        initialize: () async {
          attempts++;
          if (attempts == 1) throw StateError('temporary');
        },
        child: const MaterialApp(home: Text('AUTHORIZED RESIDENT CONTENT')),
      ),
    );
    expect(find.text('AUTHORIZED RESIDENT CONTENT'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('AUTHORIZED RESIDENT CONTENT'), findsOneWidget);
  });

  testWidgets('persistent verification errors never reveal protected content', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ResidentStartupGate(
        initialize: () async {
          attempts++;
          throw StateError('attestation unavailable');
        },
        child: const MaterialApp(home: Text('AUTHORIZED RESIDENT CONTENT')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();
    expect(attempts, 3);
    expect(find.text('AUTHORIZED RESIDENT CONTENT'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'manual retry can recover after automatic retries are exhausted',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ResidentStartupGate(
          initialize: () async {
            attempts++;
            if (attempts <= 3) throw StateError('temporary');
          },
          child: const MaterialApp(home: Text('AUTHORIZED RESIDENT CONTENT')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(attempts, 4);
      expect(find.text('AUTHORIZED RESIDENT CONTENT'), findsOneWidget);
    },
  );
}
