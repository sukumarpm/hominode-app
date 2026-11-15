import 'package:admin_app/widgets/add_resident_modal_clean.dart';
import 'package:admin_app/data/country_dial_codes.dart';
import 'package:admin_app/widgets/phone_country_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PhoneTestTranslations extends AssetLoader {
  const _PhoneTestTranslations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      SynchronousFuture(const <String, dynamic>{});
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  for (final sample in [
    (Locale('en', 'IN'), 'IN', '🇮🇳', '+91'),
    (Locale('en', 'PH'), 'PH', '🇵🇭', '+63'),
    (Locale('en', 'US'), 'US', '🇺🇸', '+1'),
    (Locale('en', 'GB'), 'GB', '🇬🇧', '+44'),
    (Locale('en'), 'IN', '🇮🇳', '+91'),
    (Locale('en', 'ZZ'), 'IN', '🇮🇳', '+91'),
  ]) {
    testWidgets(
      'Add Resident defaults to ${sample.$2} for device locale ${sample.$1}',
      (tester) async {
        tester.platformDispatcher.localeTestValue = sample.$1;
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en')],
            path: 'assets/translations',
            assetLoader: const _PhoneTestTranslations(),
            startLocale: const Locale('en'),
            saveLocale: false,
            child: ScreenUtilInit(
              designSize: const Size(800, 1000),
              builder: (context, child) => MaterialApp(
                home: Scaffold(body: AddResidentModal(onSubmit: (_) async {})),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final selector = find.byKey(const ValueKey('resident-phone-country'));
        final widget = tester.widget<PhoneCountrySelector>(selector);
        expect(widget.selectedCountry?.isoCode, sample.$2);
        expect(widget.useAdminTheme, isTrue);
        expect(
          find.descendant(of: selector, matching: find.text(sample.$3)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: selector, matching: find.text(sample.$4)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: selector, matching: find.text('Country')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final sample in [
    ('PH', '0917 123 4567', '09171234567'),
    ('IN', '09876543210', '09876543210'),
    ('US', '(415) 555-2671', '4155552671'),
    (null, '+63 (917) 123-4567', '+639171234567'),
    (null, '+1 (415) 555-2671', '+14155552671'),
    (null, '+44 20 7946 0958', '+442079460958'),
    ('IN', '+63 (917) 123-4567', '+639171234567'),
    ('PH', '+1 (415) 555-2671', '+14155552671'),
  ]) {
    testWidgets(
      'Add Resident passes explicit phone country and preserves ${sample.$2}',
      (tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'IN');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ResidentModel? submitted;
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en')],
            path: 'assets/translations',
            assetLoader: const _PhoneTestTranslations(),
            startLocale: const Locale('en'),
            saveLocale: false,
            child: Builder(
              builder: (context) => ScreenUtilInit(
                designSize: const Size(1000, 1400),
                builder: (context, child) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () => AddResidentModal.show(
                          context,
                          loadUnits: () async => const [
                            ResidentUnitOption(
                              buildingId: 'building-a',
                              flatId: 'flat-a',
                              label: 'A101',
                              buildingName: 'Tower A',
                            ),
                          ],
                          onSubmit: (value) async {
                            submitted = value;
                          },
                        ),
                        child: const Text('Open Add Resident'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Add Resident'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Phone Test Resident',
        );
        if (sample.$1 != null) {
          await tester.tap(
            find.byKey(const ValueKey('resident-phone-country')),
          );
          await tester.pumpAndSettle();
          final country = kCountryDialCodes.firstWhere(
            (country) => country.isoCode == sample.$1,
          );
          final search = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          );
          expect(tester.widget<TextField>(search).autofocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          // Exercise name, ISO and dial-code queries through the login search.
          final query = sample.$1 == 'US'
              ? '+1'
              : sample.$1 == 'IN'
              ? 'IN'
              : 'Philippines';
          await tester.enterText(search, query);
          await tester.pumpAndSettle();
          expect(find.byType(ListTile), findsWidgets);
          await tester.enterText(search, country.name);
          await tester.pumpAndSettle();
          final option = find.ancestor(
            of: find.text(country.name),
            matching: find.byType(ListTile),
          );
          expect(
            find.descendant(of: option, matching: find.text(country.flag)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: option, matching: find.text(country.dialCode)),
            findsOneWidget,
          );
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          final selector = tester.widget<PhoneCountrySelector>(
            find.byKey(const ValueKey('resident-phone-country')),
          );
          expect(selector.selectedCountry?.isoCode, country.isoCode);
          if (sample.$2 == '0917 123 4567') {
            // Reopening highlights the same selection. Empty results and cancel
            // leave the form's selection and the login preference untouched.
            await tester.tap(
              find.byKey(const ValueKey('resident-phone-country')),
            );
            await tester.pumpAndSettle();
            final reopenedSearch = find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(TextField),
            );
            await tester.enterText(reopenedSearch, country.name);
            await tester.pumpAndSettle();
            expect(find.byIcon(Icons.check_circle), findsOneWidget);
            await tester.enterText(reopenedSearch, 'not-a-country-xyz');
            await tester.pumpAndSettle();
            expect(find.text('no_countries_found'), findsOneWidget);
            await tester.tap(find.widgetWithIcon(IconButton, Icons.close).last);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<PhoneCountrySelector>(
                    find.byKey(const ValueKey('resident-phone-country')),
                  )
                  .selectedCountry
                  ?.isoCode,
              country.isoCode,
            );
            expect(
              (await SharedPreferences.getInstance()).getString(
                'admin_login_country_iso2',
              ),
              isNull,
            );
          }
        }
        await tester.enterText(
          find.byKey(const ValueKey('resident-phone-input')),
          sample.$2,
        );
        // Locate the form's button independently of translated capitalization.
        final buildingField = find.byKey(const ValueKey('resident-building'));
        await tester.ensureVisible(buildingField);
        await tester.pumpAndSettle();
        await tester.tap(buildingField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tower A').last);
        await tester.pumpAndSettle();
        final unitField = find.byKey(const ValueKey('resident-unit'));
        await tester.ensureVisible(unitField);
        await tester.pumpAndSettle();
        await tester.tap(unitField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('A101').last);
        await tester.pumpAndSettle();
        final formButton = find.descendant(
          of: find.byType(Form),
          matching: find.byType(ElevatedButton),
        );
        await tester.ensureVisible(formButton);
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(formButton).onPressed, isNotNull);
        await tester.tap(formButton);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(submitted?.phone, sample.$3);
        expect(submitted?.phoneCountryCode, sample.$1 ?? 'IN');
        expect(submitted?.buildingId, 'building-a');
        expect(submitted?.flatId, 'flat-a');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
