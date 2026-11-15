import 'package:admin_app/data/country_dial_codes.dart';
import 'package:admin_app/widgets/phone_country_picker.dart';
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

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  for (final admin in [false, true]) {
    testWidgets(
      '${admin ? 'Admin override' : 'Login default'} retains its colors, search and selection',
      (tester) async {
        var selected = kCountryDialCodes.firstWhere(
          (country) => country.isoCode == 'IN',
        );
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en')],
            path: 'assets/translations',
            assetLoader: const _Translations(),
            startLocale: const Locale('en'),
            saveLocale: false,
            child: ScreenUtilInit(
              designSize: const Size(800, 600),
              builder: (context, child) => MaterialApp(
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => PhoneCountrySelector(
                      selectedCountry: selected,
                      useAdminTheme: admin,
                      onTap: () async {
                        final country = admin
                            ? await showPhoneCountryPicker(
                                context,
                                selectedCountry: selected,
                                useAdminTheme: true,
                              )
                            : await showPhoneCountryPicker(
                                context,
                                selectedCountry: selected,
                              );
                        if (country != null) setState(() => selected = country);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ink = tester.widget<Ink>(find.byType(Ink));
        final decoration = ink.decoration! as BoxDecoration;
        expect(
          decoration.color,
          admin ? Colors.white : const Color(0xFF0A3034),
        );
        expect(
          (decoration.border! as Border).top.color,
          admin ? const Color(0xFFE5E7EB) : const Color(0xFF28675F),
        );
        await tester.tap(find.byType(PhoneCountrySelector));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        final background = tester.widget<Container>(
          find.descendant(of: sheet, matching: find.byType(Container)).first,
        );
        expect(
          (background.decoration! as BoxDecoration).color,
          admin ? Colors.white : const Color(0xFF061F24),
        );
        final search = find.descendant(
          of: sheet,
          matching: find.byType(TextField),
        );
        final field = tester.widget<TextField>(search);
        expect(field.autofocus, isTrue);
        expect(
          field.decoration?.fillColor,
          admin ? const Color(0xFFF9FAFB) : const Color(0xFF092D32),
        );
        expect(
          (field.decoration?.focusedBorder as OutlineInputBorder)
              .borderSide
              .color,
          admin ? const Color(0xFF0E4778) : const Color(0xFF58E3BE),
        );
        await tester.enterText(search, '+63');
        await tester.pumpAndSettle();
        expect(find.text('Philippines'), findsOneWidget);
        expect(find.text('🇵🇭'), findsOneWidget);
        await tester.tap(find.text('Philippines'));
        await tester.pumpAndSettle();
        expect(selected.isoCode, 'PH');
        expect(find.text('+63'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
