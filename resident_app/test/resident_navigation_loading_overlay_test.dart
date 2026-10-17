import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_navigation_loading_overlay.dart';

void main() {
  testWidgets(
    'keeps the page visible, blocks duplicate taps and clears on success',
    (tester) async {
      final harness = _LoadingHarness();
      addTearDown(harness.pageTapCount.dispose);
      await tester.pumpWidget(MaterialApp(home: harness));
      await tester.pump();

      await tester.tap(find.text('Run navigation check'));
      await tester.pump();
      expect(find.text('Current page'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Current page'), warnIfMissed: false);
      expect(harness.pageTapCount.value, 0);

      harness.completer.complete();
      await tester.pumpAndSettle();
      expect(find.text('Current page'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clears the in-place overlay after a failed operation', (
    tester,
  ) async {
    final harness = _LoadingHarness();
    addTearDown(harness.pageTapCount.dispose);
    await tester.pumpWidget(MaterialApp(home: harness));
    await tester.pump();

    await tester.tap(find.text('Run navigation check'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    harness.completer.completeError(StateError('expected test error'));
    await tester.pumpAndSettle();
    expect(find.text('Current page'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _LoadingHarness extends StatefulWidget {
  _LoadingHarness();

  final Completer<void> completer = Completer<void>();
  final ValueNotifier<int> pageTapCount = ValueNotifier<int>(0);

  @override
  State<_LoadingHarness> createState() => _LoadingHarnessState();
}

class _LoadingHarnessState extends State<_LoadingHarness> {
  bool _loading = false;

  Future<void> _run() async {
    try {
      await runWithNavigationLoading<void>(
        onLoadingChanged: (loading) => setState(() => _loading = loading),
        operation: () => widget.completer.future,
      );
    } catch (_) {
      // The screen handles the operation error; the helper must still clear.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ResidentNavigationLoadingOverlay(
      loading: _loading,
      child: Column(
        children: [
          TextButton(
            onPressed: _run,
            child: const Text('Run navigation check'),
          ),
          GestureDetector(
            onTap: () => widget.pageTapCount.value++,
            child: const Text('Current page'),
          ),
        ],
      ),
    ),
  );
}
