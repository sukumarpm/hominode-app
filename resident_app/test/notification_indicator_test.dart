import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_notification_button.dart';

void main() {
  testWidgets('ordinary widget rebuilds retain exactly one subscription', (
    tester,
  ) async {
    final source = _Counts();
    addTearDown(source.close);
    final state = await _mount(tester, source);
    source.add(3);
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      state.update();
      await tester.pumpAndSettle();
    }
    expect(source.created, 1);
    expect(source.cancelled, 0);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Home visibility round trip creates a fresh stream after cancellation',
    (tester) async {
      final source = _Counts();
      addTearDown(source.close);
      final state = await _mount(tester, source);
      source.add(4);
      await tester.pumpAndSettle();
      state.update(active: false);
      await tester.pumpAndSettle();
      expect(source.cancelled, 1);
      expect(source.hasListener, false);
      expect(find.text('4'), findsNothing);
      state.update(active: true);
      await tester.pumpAndSettle();
      expect(source.created, 2);
      expect(source.hasListener, true);
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      source.add(2);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'replacing the stream source cancels old data and resets the badge',
    (tester) async {
      final first = _Counts(), second = _Counts();
      addTearDown(first.close);
      addTearDown(second.close);
      final state = await _mount(tester, first);
      first.add(8);
      await tester.pumpAndSettle();
      state.update(source: second);
      await tester.pumpAndSettle();
      expect(first.hasListener, false);
      expect(first.cancelled, 1);
      expect(find.text('8'), findsNothing);
      first.add(9);
      second.add(1);
      await tester.pumpAndSettle();
      expect(find.text('9'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'tenant-key replacement starts a fresh consumer and rejects stale counts',
    (tester) async {
      final source = _Counts();
      addTearDown(source.close);
      final state = await _mount(tester, source);
      final previous = source.controllers.single;
      source.add(5);
      await tester.pumpAndSettle();
      state.update(scope: 'other-resident/other-community');
      await tester.pumpAndSettle();
      expect(source.created, 2);
      expect(previous.hasListener, false);
      expect(find.text('5'), findsNothing);
      previous.add(7);
      source.add(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'navigation and marking read preserve one live subscription on return',
    (tester) async {
      final source = _Counts();
      addTearDown(source.close);
      late _HarnessState state;
      state = await _mount(
        tester,
        source,
        onTap: (context) async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    source.add(0);
                    Navigator.pop(context);
                  },
                  child: const Text('Read and return'),
                ),
              ),
            ),
          );
          state.update();
        },
      );
      source.add(2);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read and return'));
      await tester.pumpAndSettle();
      expect(source.created, 1);
      expect(source.cancelled, 0);
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('disposal cancels the only listener and ignores later events', (
    tester,
  ) async {
    final source = _Counts();
    addTearDown(source.close);
    await _mount(tester, source);
    await tester.pumpWidget(const SizedBox());
    expect(source.hasListener, false);
    expect(source.cancelled, 1);
    source.add(10);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'mobile resizing, enlarged text and RTL cause no subscription crash or overflow',
    (tester) async {
      final source = _Counts();
      addTearDown(source.close);
      final state = await _mount(tester, source);
      source.add(120);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 640);
      state.update(scale: 1.7, rtl: true);
      await tester.pumpAndSettle();
      expect(source.created, 1);
      expect(find.text('99+'), findsOneWidget);
      state.update(active: false);
      await tester.pumpAndSettle();
      state.update(active: true);
      await tester.pumpAndSettle();
      expect(source.created, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'empty inbox hides badge; unread count caps and clears after read; tap preserved',
    (tester) async {
      final stream = _Counts();
      addTearDown(stream.close);
      var taps = 0;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: ResidentNotificationButton(
                createUnreadCounts: stream.create,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      stream.add(4);
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      stream.add(120);
      await tester.pumpAndSettle();
      expect(find.text('99+'), findsOneWidget);
      stream.add(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      expect(taps, 1);
      stream.addError(StateError('permission-denied'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      expect(stream.hasListener, false);
    },
  );
}

class _Counts {
  final controllers = <StreamController<int>>[];
  int cancelled = 0;
  int get created => controllers.length;
  bool get hasListener => controllers.last.hasListener;
  Stream<int> create() {
    final controller = StreamController<int>(onCancel: () => cancelled++);
    controllers.add(controller);
    return controller.stream;
  }

  void add(int count) => controllers.last.add(count);
  void addError(Object error) => controllers.last.addError(error);
  Future<void> close() async {
    for (final controller in controllers) {
      await controller.close();
    }
  }
}

Future<_HarnessState> _mount(
  WidgetTester tester,
  _Counts source, {
  Future<void> Function(BuildContext)? onTap,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: _Harness(source: source, onTap: onTap),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

class _Harness extends StatefulWidget {
  const _Harness({required this.source, this.onTap});
  final _Counts source;
  final Future<void> Function(BuildContext)? onTap;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late _Counts _source = widget.source;
  bool _active = true, _rtl = false;
  double _scale = 1;
  String _scope = 'resident/community';
  void update({
    _Counts? source,
    bool? active,
    String? scope,
    double? scale,
    bool? rtl,
  }) {
    setState(() {
      _source = source ?? _source;
      _active = active ?? _active;
      _scope = scope ?? _scope;
      _scale = scale ?? _scale;
      _rtl = rtl ?? _rtl;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(_scale)),
      child: Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Row(
          children: [
            ResidentNotificationButton(
              key: ValueKey(_scope),
              active: _active,
              createUnreadCounts: _source.create,
              onTap: () => widget.onTap?.call(context),
            ),
            const Text('Home'),
          ],
        ),
      ),
    ),
  );
}
