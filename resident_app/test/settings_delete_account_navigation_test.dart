import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resident_app/src/providers/language_provider.dart';
import 'package:resident_app/src/screens/account_deletion_request_screen.dart';
import 'package:resident_app/src/screens/app_settings_screen.dart';
import 'package:resident_app/src/services/account_deletion_request_service.dart';
import 'deletion_test_loader.dart';

class _Language extends ChangeNotifier implements LanguageProvider {
  @override
  List<String> get supportedLanguages => ['en'];
  @override
  String get currentLanguageCode => 'en';
  @override
  String getLanguageName(String languageCode) => 'English';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Requests implements AccountDeletionRequests {
  int reads = 0;
  int submissions = 0;
  var result = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>?> status() async {
    reads++;
    return null;
  }

  @override
  Future<Map<String, dynamic>> submit() {
    submissions++;
    return result.future;
  }

  @override
  Future<bool> requiresReauthentication() async => false;
  @override
  Future<void> beginReauthentication(
    void Function(String) onCodeSent,
    void Function(String) onError,
  ) async => throw StateError('Fresh session must not request OTP');
  @override
  Future<void> completeReauthentication(
    String verificationId,
    String code,
  ) async => throw StateError('Fresh session must not request OTP');
}

void main() {
  testWidgets(
    'Profile Settings opens deletion flow and requires confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      EasyLocalization.logger.enableLevels = [];
      final service = _Requests();
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          assetLoader: const DeletionTestAssetLoader(),
          startLocale: const Locale('en'),
          saveLocale: false,
          child: ChangeNotifierProvider<LanguageProvider>(
            create: (_) => _Language(),
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (context, _) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: AppSettingsScreen(deletionRequests: service),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(AccountDeletionRequestScreen), findsOneWidget);
      expect(
        find.textContaining('Required financial and security records'),
        findsOneWidget,
      );
      expect(service.reads, 1);
      expect(service.submissions, 0);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Request account deletion'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Request account deletion?'), findsOneWidget);
      expect(service.submissions, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.submissions, 0);
      expect(find.byType(AccountDeletionRequestScreen), findsOneWidget);

      Future<void> confirm() async {
        await tester.tap(find.byKey(const ValueKey('deletion-primary')));
        await tester.pumpAndSettle();
        if (find.text('Confirm request').evaluate().isNotEmpty) {
          await tester.tap(find.text('Confirm request'));
        }
        await tester.pumpAndSettle();
      }

      await confirm();
      expect(service.submissions, 1);
      expect(find.text('Processing…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      service.result.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Processing failed'), findsOneWidget);
      service.result = Completer<Map<String, dynamic>>();
      await confirm();
      expect(service.submissions, 2);
      service.result.complete({
        'requestId': 'request-test',
        'status': 'pending_verification',
      });
      await tester.pumpAndSettle();
      expect(find.text('Verification required'), findsOneWidget);
      expect(find.text('Reference: request-test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
