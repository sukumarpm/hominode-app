import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:resident_app/src/widgets/localized_text.dart';

import 'localization_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeTestLocalization);

  testWidgets('English assets resolve known UI keys in the shared test app', (
    tester,
  ) async {
    await pumpEnglishLocalizedWidget(
      tester,
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: Builder(builder: (context) => Text('pay_via_upi'.tr())),
        ),
      ),
    );
    expect(find.text('Pay via UPI'), findsOneWidget);
  });

  testWidgets('visitor purpose hint follows the selected language', (
    tester,
  ) async {
    await tester.pumpWidget(
      withResidentLocalization(
        (context) => localizedMaterialApp(
          context,
          home: Builder(
            builder: (context) =>
                Scaffold(body: Text('visitor_purpose_example'.tr())),
          ),
        ),
        startLocale: const Locale('ta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('எ.கா., தனிப்பட்ட வருகை'), findsOneWidget);
  });

  test(
    'Release 1 locales have matching keys and interpolation placeholders',
    () async {
      const locales = ['en', 'ta', 'hi', 'es', 'ar', 'ml', 'te', 'kn'];
      final loaded = await Future.wait(
        locales.map(
          (locale) => rootBundle.loadString('assets/translations/$locale.json'),
        ),
      );
      final translations = <String, Map<String, dynamic>>{
        for (var index = 0; index < locales.length; index++)
          locales[index]: jsonDecode(loaded[index]) as Map<String, dynamic>,
      };

      final english = translations['en']!;
      final englishKeys = english.keys.toSet();
      for (final locale in locales.skip(1)) {
        final localized = translations[locale]!;
        expect(
          localized.keys.toSet(),
          englishKeys,
          reason: '$locale key parity',
        );
        for (final key in englishKeys) {
          final expected = _placeholders(english[key].toString());
          expect(
            _placeholders(localized[key].toString()),
            expected,
            reason: '$locale placeholder parity for $key',
          );
        }
      }

      for (final locale in locales) {
        final localized = translations[locale]!;
        for (final key in [
          'home',
          'visitors',
          'payments',
          'pending_admin_verification',
          'partially_paid',
          'credit_applied',
          'visitor_status_entry_denied',
          'view_receipt',
          'nav_home',
          'nav_facilities',
          'nav_community',
          'nav_payments',
          'nav_more',
          'visitor_purpose_example',
        ]) {
          expect(localized[key], isNot(key), reason: '$locale missing $key');
        }
      }

      for (final locale in ['ml', 'te', 'kn']) {
        for (final key in [
          'home',
          'visitors',
          'pending_admin_verification',
          'partially_paid',
          'visitor_not_found',
        ]) {
          expect(
            translations[locale]![key],
            isNot(english[key]),
            reason: '$locale should translate $key',
          );
        }
      }
    },
  );

  test('literal Resident localization references exist in every locale', () async {
    const locales = ['en', 'ta', 'hi', 'es', 'ar', 'ml', 'te', 'kn'];
    final maps = <String, Map<String, dynamic>>{};
    for (final locale in locales) {
      maps[locale] =
          jsonDecode(
                await rootBundle.loadString('assets/translations/$locale.json'),
              )
              as Map<String, dynamic>;
    }
    final mainSource = await File('lib/main.dart').readAsString();
    expect(mainSource, contains("path: 'assets/translations'"));
    for (final locale in locales) {
      expect(mainSource, contains("Locale('$locale')"));
    }

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final callPatterns = [
      RegExp(r'''(?:'([^'\n]+)'|"([^"\n]+)")\s*\.tr\s*\('''),
      RegExp(
        r'''\bLocalized(?:Text|Button|TextButton|OutlinedButton|AppBarTitle|Tooltip)\s*\(\s*(?:'([^'\n]+)'|"([^"\n]+)")''',
      ),
      RegExp(
        r'''\b(?:translate|t|tr)\(\s*(?:context\s*,\s*)?['"]([^'"]+)['"]''',
      ),
    ];
    final missing = <String>[];
    final unresolvedWidgetKeys = <String>[];
    final englishKeys = maps['en']!.keys.toSet();
    final rawWidgetPatterns = [
      RegExp(
        r'''\b(?:Text|SelectableText)\s*\(\s*(['"])([A-Za-z][A-Za-z0-9_]*_[A-Za-z0-9_]*)\1(?!\s*\.tr)''',
      ),
      RegExp(
        r'''\b(?:title|subtitle|label|labelText|hintText|tooltip|message)\s*:\s*(['"])([A-Za-z][A-Za-z0-9_]*_[A-Za-z0-9_]*)\1(?!\s*\.tr)''',
      ),
    ];
    for (final file in files) {
      var source = await file.readAsString();
      source = source
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
      for (final pattern in callPatterns) {
        for (final match in pattern.allMatches(source)) {
          final key = match.group(1) ?? match.group(2)!;
          final missingLocales = locales
              .where((locale) => !maps[locale]!.containsKey(key))
              .toList();
          if (missingLocales.isNotEmpty) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            missing.add('${file.path}:$line "$key" missing in $missingLocales');
          }
        }
      }
      for (final pattern in rawWidgetPatterns) {
        for (final match in pattern.allMatches(source)) {
          final key = match.group(2)!;
          if (!englishKeys.contains(key)) continue;
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          unresolvedWidgetKeys.add('${file.path}:$line renders key "$key" raw');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
    expect(
      unresolvedWidgetKeys,
      isEmpty,
      reason: unresolvedWidgetKeys.join('\n'),
    );

    for (final locale in locales) {
      for (final entry in maps[locale]!.entries) {
        expect(entry.value, isA<String>(), reason: '$locale:${entry.key}');
        expect(
          entry.value.toString().trim(),
          isNotEmpty,
          reason: '$locale:${entry.key}',
        );
        if (entry.key.contains('_')) {
          expect(
            entry.value,
            isNot(entry.key),
            reason: '$locale:${entry.key} is unresolved',
          );
        }
      }
    }
  });

  testWidgets(
    'Profile family and vehicle label resolves in all supported locales',
    (tester) async {
      const expected = {
        'en': 'Family Members & Vehicles',
        'ta': 'குடும்ப உறுப்பினர்கள் மற்றும் வாகனங்கள்',
        'hi': 'परिवार के सदस्य और वाहन',
        'es': 'Familia y vehículos',
        'ar': 'أفراد العائلة والمركبات',
        'ml': 'കുടുംബാംഗങ്ങളും വാഹനങ്ങളും',
        'te': 'కుటుంబ సభ్యులు మరియు వాహనాలు',
        'kn': 'ಕುಟುಂಬ ಸದಸ್ಯರು ಮತ್ತು ವಾಹನಗಳು',
      };
      await tester.pumpWidget(
        withResidentLocalization(
          (context) => localizedMaterialApp(
            context,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: Builder(
                builder: (screenContext) => Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text('family_members_vehicles'.tr()),
                        const LocalizedText('family_members_vehicles'),
                        for (final locale in expected.keys)
                          TextButton(
                            onPressed: () =>
                                screenContext.setLocale(Locale(locale)),
                            child: Text(locale),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final entry in expected.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(
          find.text(entry.value),
          findsNWidgets(2),
          reason:
              '${entry.key}: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList()}',
        );
        expect(find.text('family_members_vehicles'), findsNothing);
        if (entry.key == 'ar') {
          expect(
            Directionality.of(tester.element(find.byType(Scaffold))),
            ui.TextDirection.rtl,
          );
        }
        expect(tester.takeException(), isNull, reason: entry.key);
      }
    },
  );
}

Set<String> _placeholders(String value) =>
    RegExp(r'\{([^{}]+)\}').allMatches(value).map((m) => m[1]!).toSet();
