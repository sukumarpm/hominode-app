import 'dart:async';

import 'package:admin_app/services/visitor_service.dart';
import 'package:admin_app/visitor_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    await tester.pumpWidget(_testApp(service));
    await tester.pumpAndSettle();

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(service.rejectedVisitorIds, ['queen-doc-id']);
    expect(find.text('Queen request rejected'), findsOneWidget);
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

    await tester.pumpWidget(_testApp(service));
    await tester.pumpAndSettle();

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pump();

    expect(find.text('Queen request rejected'), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Queen request rejected'), findsOneWidget);
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

    await tester.pumpWidget(_testApp(service));
    await tester.pumpAndSettle();

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Queen request rejected'), findsNothing);
    expect(find.textContaining('Failed to reject visitor:'), findsOneWidget);
  });
}

Widget _testApp(VisitorWorkflowService service) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    splitScreenMode: true,
    child: VisitorManagementScreen(visitorService: service),
    builder: (_, child) => MaterialApp(home: child),
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
  Future<void> approveVisitor(String visitorId) async {}

  @override
  Future<void> checkInVisitor(String visitorId) async {}

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
