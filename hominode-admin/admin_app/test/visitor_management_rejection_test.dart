import 'dart:async';

import 'package:admin_app/services/visitor_service.dart';
import 'package:admin_app/visitor_management_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final locale in ['en', 'ta', 'hi', 'es', 'ar']) {
      await rootBundle.loadString('assets/translations/$locale.json');
    }
  });

  testWidgets('reject targets the intended visitor document id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
    );

    await _pumpVisitorApp(tester, service);

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(service.rejectedVisitorIds, ['queen-doc-id']);
    expect(find.text('Queen’s request was rejected.'), findsOneWidget);
  });

  testWidgets('admin approval does not check the visitor in', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
    );

    await _pumpVisitorApp(tester, service);

    final approveButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).first,
    );
    approveButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(service.approvedVisitorIds, ['queen-doc-id']);
    expect(
      find.textContaining('approved. Security can check in'),
      findsOneWidget,
    );
  });

  testWidgets('visitor management uses Arabic text direction', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpVisitorApp(
      tester,
      _FakeVisitorWorkflowService(),
      locale: const Locale('ar'),
    );

    final title = find.text('إدارة الزوار').last;
    expect(find.text('إدارة الزوار'), findsNWidgets(2));
    expect(Directionality.of(tester.element(title)).name, 'rtl');
  });

  testWidgets('success is reported only after reject write succeeds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final completer = Completer<void>();
    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
      rejectCompleter: completer,
    );

    await _pumpVisitorApp(tester, service);

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pump();

    expect(find.text('Queen’s request was rejected.'), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Queen’s request was rejected.'), findsOneWidget);
  });

  testWidgets('failed reject does not report successful rejection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
      rejectError: Exception('permission-denied'),
    );

    await _pumpVisitorApp(tester, service);

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Queen’s request was rejected.'), findsNothing);
    expect(find.textContaining('Failed to reject visitor:'), findsOneWidget);
  });
}

Future<void> _pumpVisitorApp(
  WidgetTester tester,
  VisitorWorkflowService service, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_testApp(service, locale: locale));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Widget _testApp(
  VisitorWorkflowService service, {
  Locale locale = const Locale('en'),
}) {
  return EasyLocalization(
    supportedLocales: const [
      Locale('en'),
      Locale('ta'),
      Locale('hi'),
      Locale('es'),
      Locale('ar'),
    ],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    saveLocale: false,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      child: VisitorManagementScreen(visitorService: service),
      builder: (context, child) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: child,
      ),
    ),
  );
}

class _FakeVisitorWorkflowService implements VisitorWorkflowService {
  _FakeVisitorWorkflowService({
    List<VisitorModel>? pendingVisitors,
    this.rejectCompleter,
    this.rejectError,
  }) : _pendingVisitors = pendingVisitors ?? const [];

  final List<VisitorModel> _pendingVisitors;
  final Completer<void>? rejectCompleter;
  final Object? rejectError;
  final List<String> approvedVisitorIds = <String>[];
  final List<String> rejectedVisitorIds = <String>[];

  @override
  Stream<List<VisitorModel>> getPendingVisitors() =>
      Stream.value(_pendingVisitors);

  @override
  Stream<List<VisitorModel>> getActiveVisitors() =>
      const Stream<List<VisitorModel>>.empty();

  @override
  Stream<List<VisitorModel>> getHistoryVisitors() =>
      const Stream<List<VisitorModel>>.empty();

  @override
  Future<void> approveVisitor(String visitorId) async {
    approvedVisitorIds.add(visitorId);
  }

  @override
  Future<void> checkOutVisitor(String visitorId) async {}

  @override
  Future<void> rejectVisitor(String visitorId) async {
    rejectedVisitorIds.add(visitorId);
    if (rejectError != null) {
      throw rejectError!;
    }
    if (rejectCompleter != null) {
      await rejectCompleter!.future;
    }
  }
}
