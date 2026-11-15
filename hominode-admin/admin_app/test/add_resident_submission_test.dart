import 'dart:async';

import 'package:admin_app/widgets/add_resident_modal_clean.dart';
import 'package:admin_app/widgets/phone_country_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      SynchronousFuture(const {});
}

Future<void> _openForm(
  WidgetTester tester,
  Future<void> Function(ResidentModel) save, {
  String phone = '+63 9400000000',
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'PH');
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      assetLoader: const _Translations(),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: ScreenUtilInit(
        designSize: const Size(1000, 1400),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddResidentModal.show(
                  context,
                  onSubmit: save,
                  loadUnits: () async => const [
                    ResidentUnitOption(
                      buildingId: 'building-a',
                      flatId: 'flat-a',
                      label: 'A101',
                      buildingName: 'Tower A',
                    ),
                  ],
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('resident-name-input')),
    'Retained Resident',
  );
  await tester.enterText(
    find.byKey(const ValueKey('resident-phone-input')),
    phone,
  );
  await tester.enterText(
    find.byKey(const ValueKey('resident-email-input')),
    'resident@example.com',
  );
  final type = find.byKey(const ValueKey('resident-type'));
  await tester.ensureVisible(type);
  await tester.pumpAndSettle();
  await tester.tap(type);
  await tester.pumpAndSettle();
  await tester.tap(find.text('tenant').last);
  await tester.pumpAndSettle();
  final building = find.byKey(const ValueKey('resident-building'));
  await tester.ensureVisible(building);
  await tester.pumpAndSettle();
  await tester.tap(building);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tower A').last);
  await tester.pumpAndSettle();
  final unit = find.byKey(const ValueKey('resident-unit'));
  await tester.ensureVisible(unit);
  await tester.pumpAndSettle();
  await tester.tap(unit);
  await tester.pumpAndSettle();
  await tester.tap(find.text('A101').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('resident-members-input')),
    '3',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('resident-save')));
  await tester.pumpAndSettle();
}

void _expectRetained(WidgetTester tester, {String phone = '+63 9400000000'}) {
  expect(find.byType(AddResidentModal), findsOneWidget);
  for (final entry in {
    'resident-name-input': 'Retained Resident',
    'resident-phone-input': phone,
    'resident-email-input': 'resident@example.com',
    'resident-members-input': '3',
  }.entries) {
    expect(
      tester
          .widget<TextFormField>(find.byKey(ValueKey(entry.key)))
          .controller
          ?.text,
      entry.value,
    );
  }
  expect(
    tester
        .state<FormFieldState<String>>(
          find.byKey(const ValueKey('resident-type')),
        )
        .value,
    'tenant',
  );
  expect(
    tester
        .state<FormFieldState<ResidentUnitOption>>(
          find.byKey(const ValueKey('resident-unit')),
        )
        .value
        ?.flatId,
    'flat-a',
  );
  expect(
    tester
        .widget<PhoneCountrySelector>(
          find.byKey(const ValueKey('resident-phone-country')),
        )
        .selectedCountry
        ?.isoCode,
    'PH',
  );
  expect(
    tester
        .widget<ElevatedButton>(find.byKey(const ValueKey('resident-save')))
        .onPressed,
    isNotNull,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  testWidgets(
    'invalid phone keeps the form and all values; correcting it can save',
    (tester) async {
      var calls = 0;
      await _openForm(tester, (_) async {
        calls++;
      }, phone: '++639400000000');
      await tester.tap(find.byKey(const ValueKey('resident-save')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      _expectRetained(tester, phone: '++639400000000');
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const ValueKey('resident-phone-input')),
            )
            .errorText,
        isNotNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('resident-phone-input')),
        '+63 9400000000',
      );
      await tester.tap(find.byKey(const ValueKey('resident-save')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(AddResidentModal), findsNothing);
    },
  );

  for (final sample in [
    (
      'invalid-argument',
      'Enter a valid resident phone number.',
      'resident-phone-input',
    ),
    (
      'already-exists',
      'A resident profile already uses this phone.',
      'resident-phone-input',
    ),
    ('failed-precondition', 'This unit is not vacant.', 'resident-unit'),
    ('invalid-argument', 'Select a valid unit.', 'resident-unit'),
    ('permission-denied', 'An authorized active Admin is required.', null),
    ('unavailable', 'Network unavailable', null),
    ('internal', 'Resident could not be added.', null),
  ]) {
    testWidgets(
      '${sample.$1}: ${sample.$2} keeps all fields and allows retry',
      (tester) async {
        var calls = 0;
        await _openForm(tester, (_) async {
          calls++;
          throw FirebaseFunctionsException(code: sample.$1, message: sample.$2);
        });
        await tester.tap(find.byKey(const ValueKey('resident-save')));
        await tester.pumpAndSettle();
        expect(calls, 1);
        _expectRetained(tester);
        if (sample.$3 == 'resident-unit') {
          expect(
            tester
                .state<FormFieldState<ResidentUnitOption>>(
                  find.byKey(ValueKey<String>(sample.$3!)),
                )
                .errorText,
            sample.$2,
          );
        } else if (sample.$3 != null) {
          expect(
            tester
                .state<FormFieldState<String>>(
                  find.byKey(ValueKey<String>(sample.$3!)),
                )
                .errorText,
            sample.$2,
          );
        } else {
          expect(
            find.byKey(const ValueKey('resident-submit-error')),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(find.byKey(const ValueKey('resident-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('resident-save')));
        await tester.pumpAndSettle();
        expect(calls, 2);
        _expectRetained(tester);
      },
    );
  }

  testWidgets(
    'awaits creation, blocks duplicate submissions/back, and closes only on success',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      ResidentModel? sent;
      await _openForm(tester, (value) async {
        calls++;
        sent = value;
        await pending.future;
      }, phone: '9400000000');
      await tester.tap(find.byKey(const ValueKey('resident-save')));
      await tester.tap(find.byKey(const ValueKey('resident-save')));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(AddResidentModal), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('resident-save')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AddResidentModal), findsOneWidget);
      expect(sent?.phone, '+639400000000');
      expect(sent?.phoneCountryCode, 'PH');
      expect(sent?.buildingId, 'building-a');
      expect(sent?.flatId, 'flat-a');
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AddResidentModal), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
