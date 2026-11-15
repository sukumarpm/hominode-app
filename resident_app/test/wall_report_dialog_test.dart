import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/post_firestore_service.dart';
import 'package:resident_app/src/widgets/wall_report_dialog.dart';
import 'package:resident_app/src/providers/theme_provider.dart';

void main() {
  for (final comment in [false, true]) {
    test(
      'confirmed ${comment ? 'comment' : 'post'} report uses the existing schema and preserves duplicate results',
      () async {
        var calls = 0;
        final service = PostFirestoreService(
          moderationCall: (name, data) async {
            expect(name, 'reportWallContent');
            expect(data, {
              'postId': 'post',
              if (comment) 'commentId': 'comment',
              'reason': 'Spam: Repeated advertising',
            });
            return {
              'success': true,
              'duplicate': calls++ > 0,
              'reportId': 'report',
            };
          },
        );
        Future<ServiceResult> report() => comment
            ? service.reportWallContent(
                'post',
                commentId: 'comment',
                reason: 'Spam: Repeated advertising',
              )
            : service.reportPost('post', 'Spam: Repeated advertising');
        expect((await report()).success, true);
        final duplicate = await report();
        expect(duplicate.success, true);
        expect(duplicate.message, 'Already reported');
      },
    );
  }

  test(
    'historical, authorization and network errors are visible; malformed responses never claim success',
    () async {
      for (final failure in [
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Only new content can be reported.',
        ),
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Resident access is unavailable.',
        ),
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Temporary network failure',
        ),
      ]) {
        final service = PostFirestoreService(
          moderationCall: (_, _) async => throw failure,
        );
        final result = await service.reportPost('post', 'Spam');
        expect(result.success, false);
        expect(
          result.message,
          contains(switch (failure.code) {
            'failed-precondition' => 'predates reporting support',
            'permission-denied' => 'Resident access is unavailable',
            _ => 'Check your connection',
          }),
        );
      }
      for (final response in [
        <String, dynamic>{},
        {'success': false},
        {'success': true},
      ]) {
        final result = await PostFirestoreService(
          moderationCall: (_, _) async => response,
        ).reportPost('post', 'Other');
        expect(result.success, false);
      }
    },
  );

  Future<void> open(
    WidgetTester tester,
    Future<ServiceResult> Function(String) submit, {
    String target = 'Post',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWallReportDialog(
                context,
                targetLabel: target,
                submit: submit,
              ),
              child: const Text('Open report'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
  }

  for (final target in ['Post', 'Comment']) {
    testWidgets(
      '$target reason selection and optional explanation reach submission',
      (tester) async {
        String? reason;
        await open(tester, (value) async {
          reason = value;
          return ServiceResult(success: true, message: '$target reported');
        }, target: target);
        expect(find.text('Report $target'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        for (final text in [
          'Inappropriate content',
          'Harassment or bullying',
          'Spam',
          'Other',
        ]) {
          expect(find.text(text), findsWidgets);
        }
        await tester.tap(find.text('Harassment or bullying').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Repeated personal attacks',
        );
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();
        expect(reason, 'Harassment or bullying: Repeated personal attacks');
        expect(find.text('$target reported'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'failed submission keeps reason, shows real error, and retries without false success',
    (tester) async {
      var calls = 0;
      await open(
        tester,
        (_) async => ++calls == 1
            ? ServiceResult(success: false, message: 'Content is unavailable.')
            : ServiceResult(success: true, message: 'Post reported'),
      );
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Content is unavailable.'), findsOneWidget);
      expect(find.text('Post reported'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Post reported'), findsOneWidget);
    },
  );

  testWidgets(
    'delayed submission disables actions and prevents duplicate requests',
    (tester) async {
      final pending = Completer<ServiceResult>();
      var calls = 0;
      await open(tester, (_) {
        calls++;
        return pending.future;
      });
      final submit = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete(
        ServiceResult(success: true, message: 'Already reported'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Already reported'), findsOneWidget);
    },
  );

  testWidgets('cancel does not submit', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return ServiceResult(success: true);
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final target in ['Post', 'Comment']) {
    testWidgets(
      '$target floating explanation label stays below Reason in all focus states',
      (tester) async {
        await open(
          tester,
          (_) async => ServiceResult(success: true),
          target: target,
        );
        final field = find.byType(TextField);
        void expectSeparated() {
          final dropdown = tester.getRect(
            find.byType(DropdownButtonFormField<String>),
          );
          final label = tester.getRect(
            find.text('Additional explanation (optional)'),
          );
          expect(label.top, greaterThan(dropdown.bottom));
          expect(tester.takeException(), isNull);
        }

        expectSeparated();
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          true,
        );
        expectSeparated();
        await tester.enterText(field, 'Optional details');
        await tester.pumpAndSettle();
        expectSeparated();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expectSeparated();
      },
    );
  }

  testWidgets(
    'small screen and keyboard keep focused fields scrollable and historical errors useful',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final service = PostFirestoreService(
        moderationCall: (_, _) async => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Only new content can be reported.',
        ),
      );
      await open(tester, (reason) => service.reportPost('historical', reason));
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        true,
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(
        tester.getRect(find.text('Report')).bottom,
        lessThanOrEqualTo(568 - 260),
      );
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      final error = find.textContaining('predates reporting support');
      await tester.ensureVisible(error);
      await tester.pumpAndSettle();
      expect(error, findsOneWidget);
      expect(
        find.textContaining('Contact your community admin'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
