import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/visitor_model.dart';
import 'package:security_app/screens/visitor_management_screen.dart';
import 'package:security_app/services/visitor_service.dart';

void main() {
  testWidgets(
    'expected list is sanitized and provides no direct Approve action',
    (tester) async {
      final workflow = _FakeVisitorWorkflow(expectedVisitors: [_visitor()]);
      await tester.pumpWidget(
        MaterialApp(home: VisitorManagementScreen(visitorWorkflow: workflow)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guest One'), findsOneWidget);
      expect(find.text('Host One'), findsOneWidget);
      expect(find.text('A-101'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(
        find.text('Verify a visitor QR or manual code to record gate entry'),
        findsOneWidget,
      );
      expect(find.text('approve or reject requests'), findsNothing);
      expect(find.text('secret-qr-token'), findsNothing);
      expect(find.text('secret-manual-code'), findsNothing);
    },
  );

  testWidgets(
    'manual code uses unified verification and displays sanitized success',
    (tester) async {
      final workflow = _FakeVisitorWorkflow(expectedVisitors: [_visitor()]);
      await tester.pumpWidget(
        MaterialApp(home: VisitorManagementScreen(visitorWorkflow: workflow)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter Manual Code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'ABCD-EFGH-JKLM',
      );
      final verifyButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Verify'),
      );
      expect(verifyButton, findsOneWidget);
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      expect(workflow.verifiedManualCode, 'ABCD-EFGH-JKLM');
      expect(workflow.operationId, matches(RegExp(r'^[A-Za-z0-9_-]{32}$')));
      expect(find.text('Entry verified for Guest One'), findsOneWidget);
    },
  );

  testWidgets('bulk Mark Out displays independent per-visitor outcomes', (
    tester,
  ) async {
    final workflow = _FakeVisitorWorkflow(
      insideVisitors: [_inside('one'), _inside('two')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorManagementScreen(initialTab: 1, visitorWorkflow: workflow),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Mark Out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Mark Out'),
      ),
    );
    await tester.pumpAndSettle();

    expect(workflow.checkedOutIds, ['one', 'two']);
    expect(find.text('Guest one'), findsWidgets);
    expect(find.text('Marked out'), findsOneWidget);
    expect(find.text('Guest two'), findsWidgets);
    expect(find.text('Visitor is no longer inside.'), findsOneWidget);
  });

  testWidgets(
    'single Mark Out shows loading, blocks duplicates, then succeeds',
    (tester) async {
      final workflow = _FakeVisitorWorkflow(insideVisitors: [_inside('one')]);
      final checkout = Completer<Map<String, dynamic>>();
      workflow.checkoutCompleter = checkout;
      await tester.pumpWidget(
        MaterialApp(
          home: VisitorManagementScreen(
            initialTab: 1,
            visitorWorkflow: workflow,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mark Out').first);
      await tester.tap(find.text('Mark Out'));
      await tester.pumpAndSettle();

      expect(find.text('Mark Visitor Out?'), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'Mark Out');
      await tester.tap(confirm);
      await tester.pump();

      expect(find.text('Checking Out…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Checking Out…'),
            )
            .onPressed,
        isNull,
      );
      expect(workflow.checkoutCalls, 1);
      await tester.tap(find.text('Checking Out…'));
      await tester.pump();
      expect(workflow.checkoutCalls, 1);

      checkout.complete(_checkoutResponse(visitorIds: ['one']));
      await tester.pumpAndSettle();
      expect(find.text('Checkout Complete'), findsOneWidget);
      expect(find.text('1 marked out; 0 failed.'), findsOneWidget);
    },
  );

  testWidgets('failed checkout can retry with the same operation ID', (
    tester,
  ) async {
    final workflow = _FakeVisitorWorkflow(insideVisitors: [_inside('one')]);
    final firstAttempt = Completer<Map<String, dynamic>>();
    workflow.checkoutCompleter = firstAttempt;
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorManagementScreen(initialTab: 1, visitorWorkflow: workflow),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mark Out').first);
    await tester.tap(find.text('Mark Out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Mark Out'),
      ),
    );
    await tester.pump();
    final firstOperationId = workflow.operationIds.single;

    firstAttempt.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Checkout could not be confirmed. Please retry.'),
      findsOneWidget,
    );
    expect(find.text('Retry Checkout'), findsOneWidget);
    expect(workflow.checkoutCalls, 1);

    final retry = Completer<Map<String, dynamic>>();
    workflow.checkoutCompleter = retry;
    await tester.tap(find.text('Retry Checkout'));
    await tester.pump();
    expect(find.text('Checking Out…'), findsOneWidget);
    expect(workflow.checkoutCalls, 2);
    expect(workflow.operationIds.last, firstOperationId);

    retry.complete(_checkoutResponse(visitorIds: ['one']));
    await tester.pumpAndSettle();
    expect(find.text('Checkout Complete'), findsOneWidget);
  });

  testWidgets('bulk Mark Out shows loading and preserves partial results', (
    tester,
  ) async {
    final workflow = _FakeVisitorWorkflow(
      insideVisitors: [_inside('one'), _inside('two')],
    );
    final checkout = Completer<Map<String, dynamic>>();
    workflow.checkoutCompleter = checkout;
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorManagementScreen(initialTab: 1, visitorWorkflow: workflow),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark Out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Mark Out'),
      ),
    );
    await tester.pump();

    expect(find.text('Checking Out…'), findsOneWidget);
    expect(workflow.checkedOutIds, ['one', 'two']);
    expect(workflow.checkoutCalls, 1);

    checkout.complete(
      _checkoutResponse(visitorIds: ['one', 'two'], partial: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checkout Results'), findsOneWidget);
    expect(find.text('1 marked out; 1 failed.'), findsOneWidget);
  });

  testWidgets('inside visitor is presented as Checked In', (tester) async {
    final workflow = _FakeVisitorWorkflow(insideVisitors: [_inside('one')]);
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorManagementScreen(initialTab: 1, visitorWorkflow: workflow),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checked In'), findsWidgets);
    expect(find.text('Inside'), findsNothing);
    expect(find.text('Currently checked in'), findsOneWidget);
  });

  testWidgets('denied visitor appears in History with reason and denial time', (
    tester,
  ) async {
    final workflow = _FakeVisitorWorkflow(
      historyVisitors: [_deniedVisitor(isApproved: true)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorManagementScreen(initialTab: 2, visitorWorkflow: workflow),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guest Denied'), findsOneWidget);
    expect(find.text('Entry Denied'), findsOneWidget);
    expect(find.text('No valid ID'), findsOneWidget);
    expect(find.text('Denied:'), findsOneWidget);
    expect(find.text('Oct 11, 10:59 AM'), findsOneWidget);
  });
}

VisitorModel _visitor() => VisitorModel.fromSanitizedMap({
  'visitorId': 'expected-1', 'visitorName': 'Guest One', 'hostName': 'Host One',
  'flatId': 'flat-1', 'flatLabel': 'A-101', 'purpose': 'Delivery',
  'status': 'expected', 'adminApproved': false, 'gateAccessStatus': 'eligible',
  'expectedArrival': DateTime(2026, 10, 11).millisecondsSinceEpoch,
  // Unexpected secret fields are deliberately ignored by the model.
  'qrToken': 'secret-qr-token', 'visitorPassCode': 'secret-manual-code',
});

VisitorModel _inside(String id) => VisitorModel.fromSanitizedMap({
  'visitorId': id,
  'visitorName': 'Guest $id',
  'hostName': 'Host',
  'flatId': 'flat-$id',
  'flatLabel': 'A-${id == 'one' ? '101' : '102'}',
  'purpose': 'Visit',
  'status': 'inside',
  'adminApproved': false,
  'gateAccessStatus': 'eligible',
  'actualArrival': DateTime.now().millisecondsSinceEpoch,
});

VisitorModel _deniedVisitor({required bool isApproved}) =>
    VisitorModel.fromSanitizedMap({
      'visitorId': 'denied-1',
      'visitorName': 'Guest Denied',
      'phoneNumber': '+639171111111',
      'hostName': 'Host',
      'flatId': 'flat-a1',
      'flatLabel': 'A-101',
      'purpose': 'Visit',
      'status': 'expected',
      'adminApproved': isApproved,
      'gateAccessStatus': 'denied',
      'gateEntryDenialReason': 'No valid ID',
      'gateEntryDeniedAt': DateTime(
        2026,
        10,
        11,
        10,
        59,
      ).millisecondsSinceEpoch,
    });

class _FakeVisitorWorkflow implements VisitorWorkflow {
  _FakeVisitorWorkflow({
    this.expectedVisitors = const [],
    this.insideVisitors = const [],
    this.historyVisitors = const [],
  });

  final List<VisitorModel> expectedVisitors;
  final List<VisitorModel> insideVisitors;
  final List<VisitorModel> historyVisitors;
  String? verifiedManualCode;
  String? operationId;
  List<String> checkedOutIds = [];
  Completer<Map<String, dynamic>>? checkoutCompleter;
  int checkoutCalls = 0;
  final List<String> operationIds = [];
  int operationCounter = 0;

  @override
  String newOperationId() =>
      'operationid${(++operationCounter).toString().padLeft(21, '0')}';

  @override
  Future<List<VisitorModel>> getVisitors(String category) async =>
      switch (category) {
        'expected' => expectedVisitors,
        'inside' => insideVisitors,
        'completed' => historyVisitors,
        _ => <VisitorModel>[],
      };

  @override
  Future<Map<String, dynamic>> verifyVisitorCredential({
    String? qrToken,
    String? manualCode,
    required String operationId,
  }) async {
    verifiedManualCode = manualCode;
    this.operationId = operationId;
    return {
      'visitorId': 'expected-1',
      'visitorName': 'Guest One',
      'status': 'inside',
    };
  }

  @override
  Future<Map<String, dynamic>> denyVisitorEntry({
    required String visitorId,
    required String reason,
    required String operationId,
  }) async => {'visitorId': visitorId, 'status': 'denied'};

  @override
  Future<Map<String, dynamic>> checkoutVisitors({
    required List<String> visitorIds,
    required String operationId,
  }) {
    checkoutCalls++;
    operationIds.add(operationId);
    checkedOutIds = visitorIds;
    final completer = checkoutCompleter;
    if (completer != null) return completer.future;
    return Future.value(
      _checkoutResponse(visitorIds: visitorIds, partial: visitorIds.length > 1),
    );
  }
}

Map<String, dynamic> _checkoutResponse({
  required List<String> visitorIds,
  bool partial = false,
}) {
  final results = visitorIds.map((id) {
    final success = !partial || id == visitorIds.first;
    return {
      'visitorId': id,
      'success': success,
      if (!success) 'message': 'Visitor is no longer inside.',
    };
  }).toList();
  final succeeded = results.where((result) => result['success'] == true).length;
  final failed = results.length - succeeded;
  return {'succeeded': succeeded, 'failed': failed, 'results': results};
}
