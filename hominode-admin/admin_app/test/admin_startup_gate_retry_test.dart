import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/widgets/admin_startup_gate.dart';

void main() {
  testWidgets('temporary App Check failure retries automatically', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      AdminStartupGate(
        initialize: () async {
          attempts++;
          if (attempts == 1) throw StateError('temporary');
        },
        child: const MaterialApp(home: Text('AUTHORIZED ADMIN CONTENT')),
      ),
    );
    expect(find.text('AUTHORIZED ADMIN CONTENT'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('AUTHORIZED ADMIN CONTENT'), findsOneWidget);
  });

  testWidgets('persistent failures never display protected admin UI', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      AdminStartupGate(
        initialize: () async {
          attempts++;
          throw StateError('unavailable');
        },
        child: const MaterialApp(home: Text('AUTHORIZED ADMIN CONTENT')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();
    expect(attempts, 3);
    expect(find.text('AUTHORIZED ADMIN CONTENT'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('manual retry restores admin access after recovery', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      AdminStartupGate(
        initialize: () async {
          attempts++;
          if (attempts <= 3) throw StateError('unavailable');
        },
        child: const MaterialApp(home: Text('AUTHORIZED ADMIN CONTENT')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(attempts, 4);
    expect(find.text('AUTHORIZED ADMIN CONTENT'), findsOneWidget);
  });
}
