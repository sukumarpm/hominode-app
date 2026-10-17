import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _residentLocales = ['en', 'ta', 'hi', 'es', 'ar', 'ml', 'te', 'kn'];
final Map<String, Map<String, dynamic>> _translationsByLocale = {};

Future<void> initializeTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  for (final locale in _residentLocales) {
    _translationsByLocale[locale] =
        jsonDecode(
              await rootBundle.loadString('assets/translations/$locale.json'),
            )
            as Map<String, dynamic>;
  }
}

/// Clears the locale persisted by a previous widget test so each screen test
/// starts with its explicit [startLocale].
void resetTestLocalizationPreferences() {
  SharedPreferences.setMockInitialValues({});
}

Widget withResidentLocalization(
  WidgetBuilder appBuilder, {
  Locale startLocale = const Locale('en'),
}) => EasyLocalization(
  supportedLocales: _residentLocales.map(Locale.new).toList(),
  path: 'assets/translations',
  fallbackLocale: const Locale('en'),
  startLocale: startLocale,
  assetLoader: _ResidentTestAssetLoader(),
  child: Builder(builder: appBuilder),
);

Widget withEnglishLocalization(WidgetBuilder appBuilder) =>
    withResidentLocalization(appBuilder);

Widget localizedMaterialApp(BuildContext context, {required Widget home}) =>
    MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: home,
    );

Future<void> pumpEnglishLocalizedWidget(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

class _ResidentTestAssetLoader extends AssetLoader {
  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final translations = _translationsByLocale[locale.languageCode];
    if (translations == null) {
      throw StateError('Unsupported locale: ${locale.languageCode}');
    }
    return Map<String, dynamic>.of(translations);
  }
}
