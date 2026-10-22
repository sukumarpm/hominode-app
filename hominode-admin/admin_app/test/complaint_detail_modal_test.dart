import 'dart:async';

import 'package:admin_app/models/complaint_models.dart';
import 'package:admin_app/services/complaint_service.dart';
import 'package:admin_app/widgets/complaint_attachments.dart';
import 'package:admin_app/widgets/complaint_detail_modal.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeComplaintService extends Fake implements ComplaintService {
  int calls = 0;
  Object? failure;
  Completer<ComplaintWorkflowUpdateResult>? completer;
  Map<String, Object?>? lastUpdate;

  @override
  Future<ComplaintWorkflowUpdateResult> updateManualWorkflow({
    required String complaintId,
    required ComplaintStatus status,
    required String? assignedTeam,
    required String? assignedTo,
    required String? progressNote,
    required String? resolutionNote,
  }) {
    calls++;
    lastUpdate = {
      'complaintId': complaintId,
      'status': status,
      'assignedTeam': assignedTeam,
      'assignedTo': assignedTo,
      'progressNote': progressNote,
      'resolutionNote': resolutionNote,
    };
    if (failure != null) return Future.error(failure!);
    return completer?.future ??
        Future.value(
          const ComplaintWorkflowUpdateResult(notificationSent: true),
        );
  }
}

final _complaint = ComplaintEntry(
  id: 'complaint-1',
  priority: ComplaintPriority.high,
  status: ComplaintStatus.pending,
  title: 'Security concern',
  residentName: 'Resident',
  unit: 'A-101',
  date: DateTime(2026, 10, 22),
  category: ComplaintCategory.security,
  assignedTo: 'Security Desk', // Legacy free-text assignment.
);

Widget _app(
  ComplaintService service, {
  double textScale = 1,
  Widget? attachmentsOverride = const SizedBox.shrink(),
  ComplaintEntry? complaint,
  Function(ComplaintEntry)? onComplaintUpdated,
}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  builder: (context, child) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: ComplaintDetailModal(
        complaint: complaint ?? _complaint,
        complaintService: service,
        attachmentsOverride: attachmentsOverride,
        onComplaintUpdated: onComplaintUpdated,
      ),
    ),
  ),
);

ComplaintAttachments _attachmentWithRecord() => ComplaintAttachments(
  complaintId: _complaint.id,
  records: Stream.value({
    'communityId': 'community-a',
    // A malformed managed reference still creates a rendered attachment row
    // without requiring a network image or Firebase Storage plugin.
    'imageUrl': 'hominode-image:broken',
    'managedImageAssets': <Object?>[],
  }),
  scope: () => 'admin-1/community-a',
  sessionChanges: ChangeNotifier(),
  tokenChanges: const Stream<Object?>.empty(),
);

Widget _dialogApp(
  ComplaintService service, {
  required Widget attachments,
  Function(ComplaintEntry)? onComplaintUpdated,
}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  builder: (context, child) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open-complaint-detail'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ComplaintDetailModal(
                complaint: _complaint,
                complaintService: service,
                attachmentsOverride: attachments,
                onComplaintUpdated: onComplaintUpdated,
              ),
            ),
            child: const Text('Open complaint'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'legacy assignee text and duplicate labels do not break selection',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _FakeComplaintService();

      await tester.pumpWidget(_app(service));
      expect(find.text('Current assignment: Security Desk'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('complaint-team-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('No team selected'), findsNWidgets(2));
      expect(find.text('Security'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('status-only save omits unchanged legacy assignment fields', (
    tester,
  ) async {
    final service = _FakeComplaintService();
    await tester.pumpWidget(_app(service));
    await tester.tap(find.byKey(const ValueKey('save-complaint-update')));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(service.lastUpdate?['assignedTeam'], isNull);
    expect(service.lastUpdate?['assignedTo'], isNull);
  });

  testWidgets('starts work without staff and saves reassignment and progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeComplaintService();
    ComplaintEntry? updated;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: ComplaintDetailModal(
              complaint: _complaint,
              complaintService: service,
              attachmentsOverride: const SizedBox.shrink(),
              onComplaintUpdated: (value) => updated = value,
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('complaint-status-dropdown')),
    );
    await tester.tap(find.byKey(const ValueKey('complaint-status-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Progress').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('complaint-team-dropdown')),
    );
    await tester.tap(find.byKey(const ValueKey('complaint-team-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintenance').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'On-call technician');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Technician is inspecting the entrance.',
    );
    await tester.tap(find.byKey(const ValueKey('save-complaint-update')));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(service.lastUpdate?['status'], ComplaintStatus.inProgress);
    expect(service.lastUpdate?['assignedTeam'], 'maintenance');
    expect(service.lastUpdate?['assignedTo'], 'On-call technician');
    expect(service.lastUpdate?['progressNote'], contains('inspecting'));
    expect(updated?.status, ComplaintStatus.inProgress);
  });

  testWidgets('failed write does not call update callback or claim success', (
    tester,
  ) async {
    final service = _FakeComplaintService()..failure = StateError('denied');
    var callbackCalled = false;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: ComplaintDetailModal(
              complaint: _complaint,
              complaintService: service,
              attachmentsOverride: const SizedBox.shrink(),
              onComplaintUpdated: (_) => callbackCalled = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('save-complaint-update')));
    await tester.pumpAndSettle();

    expect(callbackCalled, isFalse);
    expect(
      find.textContaining('Complaint update failed: Bad state: denied'),
      findsOneWidget,
    );
    expect(find.text('New'), findsNWidgets(2));
  });

  testWidgets('blocks repeat submissions while the first save is pending', (
    tester,
  ) async {
    final service = _FakeComplaintService()
      ..completer = Completer<ComplaintWorkflowUpdateResult>();
    await tester.pumpWidget(_app(service));
    await tester.tap(find.byKey(const ValueKey('save-complaint-update')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-complaint-update')));
    await tester.pump();
    expect(service.calls, 1);
    service.completer!.complete(
      const ComplaintWorkflowUpdateResult(notificationSent: false),
    );
    await tester.pumpAndSettle();
    expect(service.calls, 1);
  });

  testWidgets('modal avoids overflow at enlarged text size', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_FakeComplaintService(), textScale: 1.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('attachments remain bounded inside the detail scroll view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        _FakeComplaintService(),
        attachmentsOverride: _attachmentWithRecord(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photo unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'status change with attachments persists before success on a keyboard-sized viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('complaints').doc(_complaint.id).set({
        'communityId': 'community-a',
        'residentId': 'resident-1',
        'title': _complaint.title,
        'status': 'pending',
      });
      final service = ComplaintService(
        firestore: firestore,
        adminIdProvider: () => 'admin-1',
        communityIdProvider: () => 'community-a',
        notificationSender:
            ({
              required recipientId,
              required title,
              required message,
              required metadata,
            }) async {},
      );
      ComplaintEntry? updated;

      await tester.pumpWidget(
        _dialogApp(
          service,
          attachments: _attachmentWithRecord(),
          onComplaintUpdated: (value) => updated = value,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-complaint-detail')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey('complaint-status-dropdown')),
      );
      await tester.tap(find.byKey(const ValueKey('complaint-status-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Progress').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-complaint-update')),
      );
      await tester.tap(find.byKey(const ValueKey('save-complaint-update')));
      // Allow the transaction and dialog route transition to complete, but
      // inspect the confirmation before the snack bar's timer expires.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        (await firestore.collection('complaints').doc(_complaint.id).get())
            .data()?['status'],
        'inprogress',
      );
      expect(updated?.status, ComplaintStatus.inProgress);
      expect(
        find.text('Complaint updated and resident notified.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
