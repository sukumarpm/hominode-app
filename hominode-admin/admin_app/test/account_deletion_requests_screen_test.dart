import 'dart:async';

import 'package:admin_app/account_deletion_requests_screen.dart';
import 'package:admin_app/admin_residents_page_firestore.dart';
import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/account_deletion_review_service.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

const _request = CommunityDeletionRequest(
  requestId: 'request-a',
  status: 'pending_review',
  financialReviewStatus: 'UNKNOWN_REQUIRES_REVIEW',
  reviewStatus: 'pending_admin_review',
);

class _Gateway implements AccountDeletionReviewGateway {
  List<CommunityDeletionRequest> requests = const [_request];
  String? community;
  String? requestId;
  String? finding;
  String? note;
  String? evidenceDigest;
  bool retainFinancialRecords = false;
  bool fail = false;
  bool failReassessment = false;
  bool failFinding = false;
  int findingCalls = 0;
  Completer<void>? pendingFinding;
  int listCalls = 0;
  int reassessCalls = 0;
  Map<String, dynamic> reassessmentResult = const {'status': 'pending_review'};
  Completer<Map<String, dynamic>>? pendingReassessment;

  @override
  Future<List<CommunityDeletionRequest>> list(String communityId) async {
    listCalls++;
    community = communityId;
    if (fail) throw StateError('offline');
    return requests;
  }

  @override
  Future<Map<String, dynamic>> reassess({required String requestId}) async {
    if (failReassessment) throw StateError('offline');
    reassessCalls++;
    this.requestId = requestId;
    return pendingReassessment == null
        ? reassessmentResult
        : pendingReassessment!.future;
  }

  @override
  Future<void> recordFinding({
    required String requestId,
    required String finding,
    required String note,
    String? evidenceDigest,
    bool retainFinancialRecords = false,
  }) async {
    findingCalls++;
    if (fail || failFinding) throw StateError('offline');
    if (pendingFinding != null) await pendingFinding!.future;
    this.requestId = requestId;
    this.finding = finding;
    this.note = note;
    this.evidenceDigest = evidenceDigest;
    this.retainFinancialRecords = retainFinancialRecords;
  }
}

void _authorizeCommunity() {
  AdminTenantContext.instance.initialize(
    const AdminProfile(
      uid: 'admin-a',
      phoneNumber: '+15550000001',
      role: 'admin',
      isActive: true,
      authorizedCommunityIds: ['community-a'],
    ),
  );
}

void main() {
  tearDown(AdminTenantContext.instance.clear);

  testWidgets('Resident Management entry opens the authorized request queue', (
    tester,
  ) async {
    _authorizeCommunity();
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AccountDeletionRequestsAction(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AccountDeletionRequestsScreen(service: gateway),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Account Deletion Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Account Deletion Requests'), findsOneWidget);
    expect(gateway.community, 'community-a');
  });

  testWidgets(
    'Resident Management actions wrap at narrow and normal mobile widths',
    (tester) async {
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ResidentManagementActions(
                  bulkImportTooltip: 'Bulk import',
                  pendingResidentsTooltip: 'Pending residents',
                  addLabel: 'Add',
                  onBulkImport: () {},
                  onPendingResidents: () {},
                  onDeletionRequests: () {},
                  onAddResident: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Bulk import'), findsOneWidget);
        expect(find.byTooltip('Pending residents'), findsOneWidget);
        expect(find.text('Account Deletion Requests'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('add-resident-entry')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }
    },
  );

  testWidgets('Settings opens the community deletion request screen', (
    tester,
  ) async {
    _authorizeCommunity();
    final gateway = _Gateway();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        child: MaterialApp(
          home: SettingsScreen(accountDeletionReviewService: gateway),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account Deletion Requests'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Zero dues are processed automatically'),
      findsOneWidget,
    );
    expect(gateway.community, 'community-a');
  });

  testWidgets(
    'unknown financial status stays unknown and details show safe fields',
    (tester) async {
      _authorizeCommunity();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountDeletionRequestsScreen(service: _Gateway()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Outstanding dues / settlement: Unknown: requires reconciliation',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('zero dues'), findsNothing);
      await tester.ensureVisible(find.text('Open details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      expect(
        find.text('Financial verification status: Unknown — requires review'),
        findsOneWidget,
      );
      expect(find.text('Previous review note: None recorded'), findsOneWidget);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Complete Deletion'), findsNothing);
    },
  );

  testWidgets('unpaid dues remain awaiting settlement and cannot be verified', (
    tester,
  ) async {
    _authorizeCommunity();
    final gateway = _Gateway()
      ..requests = [
        CommunityDeletionRequest(
          requestId: 'due-request',
          financialReviewStatus: 'UNKNOWN_REQUIRES_REVIEW',
          reviewStatus: 'pending_admin_review',
          financialEvidence: {
            'digest': 'b' * 64,
            'recordCount': 1,
            'outstandingMinor': 500,
            'currency': 'INR',
          },
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Outstanding dues / settlement: Outstanding dues: awaiting settlement',
      ),
      findsOneWidget,
    );
    expect(find.text('Verify financial handover'), findsNothing);
  });

  testWidgets(
    'displays backend identity, status, prior findings and dependencies',
    (tester) async {
      _authorizeCommunity();
      final request = CommunityDeletionRequest.fromMap({
        'requestId': 'request-rich',
        'createdAt': '2026-02-01T10:00:00Z',
        'status': 'pending_review',
        'reviewStatus': 'dependency_unresolved',
        'financialReviewStatus': 'UNKNOWN_REQUIRES_REVIEW',
        'resident': {'displayName': 'Resident Name', 'unit': 'Block A / 12'},
        'residentProfileStatus': 'verified',
        'reviewFinding': 'dependency_unresolved',
        'reviewNote': 'Confirm outstanding utility handover.',
        'reviewedAt': '2026-02-02T10:00:00Z',
        'reviewDueAt': '2026-02-03T10:00:00Z',
        'unresolvedDependencies': ['Utility handover is pending.'],
      });
      final gateway = _Gateway()..requests = [request];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resident Name'), findsOneWidget);
      expect(find.text('Unit: Block A / 12'), findsOneWidget);
      expect(
        find.text('Current deletion status: Pending review'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Previous note: Confirm outstanding utility handover.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Unresolved: Utility handover is pending.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Open details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      expect(find.text('Resident: Resident Name'), findsOneWidget);
      expect(
        find.text('Current deletion status: Pending review'),
        findsWidgets,
      );
      expect(
        find.text(
          'Previous review note: Confirm outstanding utility handover.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'completed request uses retained identity and hides stale queue status',
    (tester) async {
      _authorizeCommunity();
      final gateway = _Gateway()
        ..requests = [
          CommunityDeletionRequest.fromMap({
            'requestId': 'deleted-request',
            'communityId': 'community-a',
            'communityName': 'Green Wave',
            'createdAt': {'_seconds': 1777623300, '_nanoseconds': 0},
            'completedAt': {'seconds': 1777714200, 'nanoseconds': 0},
            'status': 'completed',
            'reviewStatus': 'pending_admin_review',
            'financialReviewStatus': 'VERIFIED_HANDOVER',
            'financialReviewRequired': true,
            'financialEvidence': {'outstandingMinor': 0},
            'resident': {
              'displayName': 'Resident Full Name',
              'phoneNumber': '+15550000011',
              'unit': 'Tower 4 / 1202',
              'residentType': 'tenant',
            },
            'residentProfileStatus': 'retained_after_deletion',
            'reviewFinding': 'verified_handover',
            'reviewNote': 'Settlement checked against current records.',
            'reviewedAt': '2026-05-01T09:00:00Z',
          }),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resident Full Name'), findsOneWidget);
      expect(find.text('Phone: +15550000011'), findsOneWidget);
      expect(find.text('Unit: Tower 4 / 1202'), findsOneWidget);
      expect(find.text('Community: Green Wave'), findsOneWidget);
      expect(find.text('Resident role: Tenant'), findsOneWidget);
      expect(
        find.textContaining(
          DateFormat.yMMMd().add_jm().format(
            DateTime.fromMillisecondsSinceEpoch(1777623300 * 1000).toLocal(),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          DateFormat.yMMMd().add_jm().format(
            DateTime.fromMillisecondsSinceEpoch(1777714200 * 1000).toLocal(),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Current deletion status: Account Deleted'),
        findsOneWidget,
      );
      expect(
        find.text('Outstanding dues / settlement: Financial handover verified'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Review queue status: pending_admin_review'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Open details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Current deletion status: Account Deleted'),
        findsWidgets,
      );
      expect(
        find.textContaining('Deletion completion date and time:'),
        findsOneWidget,
      );
      expect(find.textContaining('Request date and time:'), findsWidgets);
      expect(
        find.textContaining('Settlement checked against current records.'),
        findsWidgets,
      );
    },
  );

  test(
    'legacy response safely defaults missing optional fields and withholds identity',
    () {
      final request = CommunityDeletionRequest.fromMap({
        'requestId': 'old-request',
      });
      expect(request.residentProfileStatus, 'unverified_or_missing');
      expect(request.financialReviewStatus, 'UNKNOWN_REQUIRES_REVIEW');
      expect(request.unresolvedDependencies, isEmpty);
      expect(request.residentName, isNull);
    },
  );

  testWidgets(
    'completed request does not show pending financial review labels',
    (tester) async {
      _authorizeCommunity();
      final gateway = _Gateway()
        ..requests = [
          const CommunityDeletionRequest(
            requestId: 'completed',
            status: 'completed',
            financialReviewStatus: 'UNKNOWN_REQUIRES_REVIEW',
            financialReviewRequired: true,
            reviewStatus: 'pending_admin_review',
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(home: AccountDeletionRequestsScreen(service: gateway)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Financial verification: Not recorded'), findsOneWidget);
      expect(find.textContaining('requires review'), findsNothing);
      expect(find.textContaining('pending_admin_review'), findsNothing);
    },
  );

  testWidgets(
    'Admin cannot record generic findings or reject/cancel deletion',
    (tester) async {
      _authorizeCommunity();
      final gateway = _Gateway();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Record finding'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
    },
  );

  testWidgets('handover verification is offered only with verified zero dues', (
    tester,
  ) async {
    _authorizeCommunity();
    final evidence = {
      'digest': 'a' * 64,
      'recordCount': 1,
      'outstandingMinor': 0,
      'currency': 'INR',
    };
    final gateway = _Gateway()
      ..requests = [
        CommunityDeletionRequest(
          requestId: 'settled-request',
          status: 'pending_review',
          financialReviewStatus: 'UNKNOWN_REQUIRES_REVIEW',
          reviewStatus: 'pending_admin_review',
          financialEvidence: evidence,
          financialReviewRequired: true,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Outstanding dues / settlement: Zero dues: eligible for financial verification',
      ),
      findsOneWidget,
    );
    expect(find.text('Verify financial handover'), findsOneWidget);
    final verifyButton = find.widgetWithText(
      FilledButton,
      'Verify financial handover',
    );

    await tester.ensureVisible(verifyButton);
    await tester.pumpAndSettle();

    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.enterText(
      find.byType(TextField),
      'Zero dues verified against the current account.',
    );
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'Confirm settlement');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.tap(find.text('Confirm settlement'));
    await tester.pumpAndSettle();
    expect(find.text('Record review finding'), findsNothing);
    expect(gateway.finding, 'verified_handover');
    expect(gateway.evidenceDigest, evidence['digest']);
    expect(gateway.retainFinancialRecords, isTrue);
  });

  testWidgets('callable failure shows retryable error', (tester) async {
    _authorizeCommunity();
    final gateway = _Gateway()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Requests could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'verification blocks dismissal and duplicates until confirmation',
    (tester) async {
      _authorizeCommunity();
      final gateway = _Gateway()
        ..pendingFinding = Completer<void>()
        ..requests = [
          CommunityDeletionRequest(
            requestId: 'settled',
            status: 'pending_review',
            financialReviewRequired: true,
            financialReviewStatus: 'UNKNOWN_REQUIRES_REVIEW',
            reviewStatus: 'pending_admin_review',
            financialEvidence: {'digest': 'a' * 64, 'outstandingMinor': 0},
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(home: AccountDeletionRequestsScreen(service: gateway)),
      );
      await tester.pumpAndSettle();
      final verifyButton = find.widgetWithText(
        FilledButton,
        'Verify financial handover',
      );

      await tester.ensureVisible(verifyButton);
      await tester.pumpAndSettle();

      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(
        find.byType(TextField),
        'Settlement records were reviewed.',
      );
      await tester.pump();
      await tester.tap(find.text('Confirm settlement'));
      await tester.pump();
      expect(find.text('Verifying...'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Verifying...'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(gateway.findingCalls, 1);
      gateway.pendingFinding!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Financial handover verified. Deletion processing.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed verification keeps the dialog open and can be retried', (
    tester,
  ) async {
    _authorizeCommunity();
    final gateway = _Gateway()
      ..failFinding = true
      ..requests = [
        CommunityDeletionRequest(
          requestId: 'settled',
          status: 'pending_review',
          financialReviewRequired: true,
          financialReviewStatus: 'UNKNOWN_REQUIRES_REVIEW',
          reviewStatus: 'pending_admin_review',
          financialEvidence: {'digest': 'a' * 64, 'outstandingMinor': 0},
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: AccountDeletionRequestsScreen(service: gateway)),
    );
    await tester.pumpAndSettle();
    final verifyButton = find.widgetWithText(
      FilledButton,
      'Verify financial handover',
    );

    await tester.ensureVisible(verifyButton);
    await tester.pumpAndSettle();

    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.enterText(
      find.byType(TextField),
      'Settlement records were reviewed.',
    );
    await tester.pump();
    await tester.tap(find.text('Confirm settlement'));
    await tester.pumpAndSettle();
    expect(
      find.text('Financial verification could not be saved. Please retry.'),
      findsOneWidget,
    );
    gateway.failFinding = false;
    await tester.tap(find.text('Confirm settlement'));
    await tester.pumpAndSettle();
    expect(
      find.text('Financial handover verified. Deletion processing.'),
      findsOneWidget,
    );
    expect(gateway.findingCalls, 2);
  });

  testWidgets(
    'recheck is visible for pending requests with verified handover',
    (tester) async {
      _authorizeCommunity();
      final gateway = _Gateway()
        ..requests = [
          const CommunityDeletionRequest(
            requestId: 'verified-request',
            status: 'pending_review',
            financialReviewStatus: 'VERIFIED_HANDOVER',
            reviewStatus: 'handover_complete_pending_eligibility',
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recheck deletion'), findsOneWidget);
      expect(find.text('Verify financial handover'), findsNothing);
    },
  );

  testWidgets('successful reassessment refreshes the request status', (
    tester,
  ) async {
    _authorizeCommunity();
    final gateway = _Gateway()
      ..requests = [
        const CommunityDeletionRequest(
          requestId: 'pending-request',
          status: 'pending_review',
          financialReviewStatus: 'UNKNOWN_REQUIRES_REVIEW',
          reviewStatus: 'pending_admin_review',
        ),
      ]
      ..reassessmentResult = const {'status': 'eligibility_blocked'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recheck deletion'));
    await tester.pumpAndSettle();
    expect(gateway.requestId, 'pending-request');
    expect(gateway.reassessCalls, 1);
    expect(gateway.listCalls, 2);
    expect(
      find.text(
        'Deletion recheck finished. Current status: eligibility_blocked.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reassessment failure is shown to Admin', (tester) async {
    _authorizeCommunity();
    final gateway = _Gateway()..failReassessment = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recheck deletion'));
    await tester.pumpAndSettle();
    expect(
      find.text('Deletion could not be rechecked. Please retry.'),
      findsOneWidget,
    );
  });

  testWidgets('reassessment shows progress and prevents duplicate taps', (
    tester,
  ) async {
    _authorizeCommunity();
    final gateway = _Gateway()
      ..pendingReassessment = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountDeletionRequestsScreen(service: gateway)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recheck deletion'));
    await tester.pump();
    final progressButton = find.widgetWithText(OutlinedButton, 'Rechecking…');
    expect(progressButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(progressButton).onPressed, isNull);
    expect(gateway.reassessCalls, 1);
    gateway.pendingReassessment!.complete({'status': 'pending_review'});
    await tester.pumpAndSettle();
    expect(gateway.reassessCalls, 1);
  });
}
