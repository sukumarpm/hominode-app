import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Map<String, dynamic> _englishTranslations;

Future<void> initializeAdminTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  // Load real assets outside the widget test's fake-async zone.
  _englishTranslations =
      jsonDecode(await rootBundle.loadString('assets/translations/en.json'))
          as Map<String, dynamic>;
  assert(
    _englishTranslations.containsKey('resident_verify_identity_action'),
    'The bundled English asset is missing identity-proof labels.',
  );
  assert(
    _englishTranslations.containsKey('unit_units_label'),
    'The bundled English asset is missing occupancy labels.',
  );
}

Widget localizedAdminTestApp(
  Widget home, {
  Size designSize = const Size(390, 844),
}) => EasyLocalization(
  supportedLocales: const [Locale('en')],
  path: 'assets/translations',
  assetLoader: const _PreloadedEnglishAssetLoader(),
  fallbackLocale: const Locale('en'),
  startLocale: const Locale('en'),
  saveLocale: false,
  child: ScreenUtilInit(
    designSize: designSize,
    child: home,
    builder: (context, child) => MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: child,
    ),
  ),
);

// Use the real bundled JSON, loaded in setUpAll, without platform asset IO
// racing the first assertions inside a widget test's fake-async zone.
class _PreloadedEnglishAssetLoader extends AssetLoader {
  const _PreloadedEnglishAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      _englishTranslations;
}
