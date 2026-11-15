import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_app/quick_access_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/content_moderation_screen.dart';
import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/admin_tenant_context.dart';

void main() {
  tearDown(AdminTenantContext.instance.clear);
  void authorize() => AdminTenantContext.instance.initialize(
    const AdminProfile(
      uid: 'admin',
      phoneNumber: '+15550000001',
      role: 'admin',
      isActive: true,
      authorizedCommunityIds: ['A'],
    ),
  );

  testWidgets(
    'Quick Access opens the existing scoped moderation screen with reasons and history',
    (tester) async {
      authorize();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: QuickAccessPage(
              moderationBuilder: (_) => ContentModerationScreen(
                call: (name, data) async {
                  expect(name, 'listWallModerationReports');
                  expect(data['communityId'], 'A');
                  return {
                    'reports': [
                      {
                        'id': 'r',
                        'status': 'open',
                        'targetType': 'post',
                        'contentSnapshot': 'New eligible post',
                        'reason': 'Spam: Advertising',
                      },
                    ],
                    'history': [
                      {'action': 'dismiss', 'actorId': 'admin'},
                    ],
                  };
                },
              ),
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Content Moderation'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Content Moderation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Content Moderation'));
      await tester.pumpAndSettle();
      expect(find.byType(ContentModerationScreen), findsOneWidget);
      expect(find.text('New eligible post'), findsOneWidget);
      expect(find.text('Report reason: Spam: Advertising'), findsOneWidget);
      expect(find.text('Report dismissed'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Reports'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Reports'), findsOneWidget);
    },
  );

  testWidgets(
    'Quick Access requires an authorized selected community for moderation',
    (tester) async {
      AdminTenantContext.instance.clear();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => const MaterialApp(home: QuickAccessPage()),
        ),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Content Moderation'), findsNothing);
    },
  );

  testWidgets(
    'loading, callable error, retry and genuine empty queue remain distinct',
    (tester) async {
      authorize();
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ContentModerationScreen(
            call: (_, _) {
              calls++;
              return calls == 1
                  ? pending.future
                  : Future.value({'reports': [], 'history': []});
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No open reports.'), findsNothing);
      pending.completeError(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'An authorized active Admin is required.',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('An authorized active Admin is required.'),
        findsOneWidget,
      );
      expect(find.text('No open reports.'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No open reports.'), findsOneWidget);
      expect(find.text('No moderation actions yet.'), findsOneWidget);
    },
  );

  testWidgets('moderation history pagination stays in the selected community', (
    tester,
  ) async {
    authorize();
    await tester.pumpWidget(
      MaterialApp(
        home: ContentModerationScreen(
          call: (_, data) async {
            expect(data['communityId'], 'A');
            if (data['historyOffset'] == 1) {
              return {
                'history': [
                  {'action': 'hide', 'actorId': 'admin'},
                ],
                'historyTruncated': false,
              };
            }
            return {
              'reports': [],
              'history': [
                {'action': 'dismiss', 'actorId': 'admin'},
              ],
              'historyTruncated': true,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Load more history'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Load more history'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Content hidden'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Report dismissed'), findsOneWidget);
    expect(find.text('Content hidden'), findsOneWidget);
  });

  testWidgets('admin reviews and hides reported content with scoped callable', (
    tester,
  ) async {
    AdminTenantContext.instance.initialize(
      const AdminProfile(
        uid: 'admin',
        phoneNumber: '+15550000001',
        role: 'admin',
        isActive: true,
        authorizedCommunityIds: ['A'],
      ),
    );
    final calls = <Map<String, dynamic>>[];
    var hidden = false;
    Future<Map<String, dynamic>> call(
      String name,
      Map<String, dynamic> data,
    ) async {
      calls.add({'name': name, ...data});
      if (name == 'resolveWallModerationReport') {
        hidden = true;
        return {'success': true};
      }
      return {
        'reports': hidden
            ? []
            : [
                {
                  'id': 'report',
                  'status': 'open',
                  'targetType': 'comment',
                  'reason': 'Abuse',
                  'contentSnapshot': 'Abusive example',
                },
              ],
        'history': hidden
            ? [
                {'action': 'hide', 'actorId': 'admin'},
              ]
            : [],
      };
    }

    await tester.pumpWidget(
      MaterialApp(home: ContentModerationScreen(call: call)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Abusive example'), findsOneWidget);
    await tester.tap(find.text('Hide content'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm decision'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harassment or bullying').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm decision'));
    await tester.pumpAndSettle();
    expect(
      calls[1],
      equals({
        'name': 'resolveWallModerationReport',
        'communityId': 'A',
        'reportId': 'report',
        'action': 'hide',
        'reasonCode': 'harassment',
        'publicExplanation': '',
        'internalNote': '',
      }),
    );
    expect(find.text('Content hidden'), findsOneWidget);
  });
  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    testWidgets(
      'responsive moderation cards and required dismissal reasons at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        authorize();
        var resolved = false;
        final pending = Completer<Map<String, dynamic>>();
        Map<String, dynamic>? submitted;
        await tester.pumpWidget(
          MaterialApp(
            home: ContentModerationScreen(
              call: (name, data) async {
                if (name == 'resolveWallModerationReport') {
                  submitted = data;
                  resolved = true;
                  return pending.future;
                }
                return {
                  'reports': resolved
                      ? []
                      : [
                          {
                            'id': 'private-report-id',
                            'status': 'open',
                            'targetType': 'post',
                            'authorName': 'Resident Name',
                            'reason': 'Spam: Advertising',
                            'contentSnapshot': 'Post preview',
                          },
                        ],
                  'history': resolved
                      ? [
                          {
                            'id': 'audit',
                            'action': 'dismiss',
                            'targetType': 'post',
                            'authorName': 'Resident Name',
                            'actorName': 'Moderator Name',
                            'publicReason':
                                'No community guideline violation: Within the rules.',
                            'internalNote': 'Admin context',
                            'createdAtMs': 1760000000000,
                            'contentSnapshot': 'Post preview',
                          },
                        ]
                      : [],
                };
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Author: Resident Name'), findsOneWidget);
        expect(find.text('private-report-id'), findsNothing);
        await tester.ensureVisible(find.text('Dismiss report'));
        await tester.tap(find.text('Dismiss report'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm decision'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('No community guideline violation').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'Within the rules.',
        );
        await tester.enterText(find.byType(TextField).last, 'Admin context');
        final confirm = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm decision'),
            )
            .onPressed!;
        confirm();
        confirm();
        await tester.pump();
        expect(submitted, {
          'communityId': 'A',
          'reportId': 'private-report-id',
          'action': 'dismiss',
          'reasonCode': 'no_violation',
          'publicExplanation': 'Within the rules.',
          'internalNote': 'Admin context',
        });
        expect(find.text('Saving decision...'), findsOneWidget);
        pending.complete({'success': true});
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Public decision reason: No community guideline violation: Within the rules.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Moderator: Moderator Name'),
          findsOneWidget,
        );
        expect(find.text('Dismissed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('decision error retains reason and permits a safe retry', (
    tester,
  ) async {
    authorize();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ContentModerationScreen(
          call: (name, data) async {
            if (name == 'resolveWallModerationReport') {
              calls++;
              if (calls == 1) {
                throw FirebaseFunctionsException(
                  code: 'unavailable',
                  message: 'Temporary connection failure',
                );
              }
              return {'success': true};
            }
            return {
              'reports': calls < 2
                  ? [
                      {
                        'id': 'report',
                        'status': 'open',
                        'targetType': 'post',
                        'reason': 'Spam',
                        'contentSnapshot': 'Preview',
                      },
                    ]
                  : [],
              'history': [],
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hide content'));
    await tester.tap(find.text('Hide content'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm decision'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary connection failure'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(calls, 1);
    await tester.tap(find.text('Confirm decision'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('No open reports.'), findsOneWidget);
  });
}
