import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/edit_profile_screen.dart';

import 'localization_test_app.dart';

void main() {
  setUpAll(initializeTestLocalization);

  const profile = <String, dynamic>{
    'name': 'Ananya Resident',
    'email': 'ananya@example.test',
    'phone': '+91 90000 00000',
    'flatLabel': 'A-101',
  };

  Future<void> pumpProfile(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      withResidentLocalization(
        (localizationContext) => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            locale: localizationContext.locale,
            supportedLocales: localizationContext.supportedLocales,
            localizationsDelegates: localizationContext.localizationDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open-edit-profile'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MediaQuery(
                        data: MediaQueryData(
                          size: Size(width, 844),
                          textScaler: const TextScaler.linear(1.6),
                        ),
                        child: EditProfileScreen(
                          profileLoader: () async =>
                              Map<String, dynamic>.of(profile),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open edit profile'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-edit-profile')));
    await tester.pumpAndSettle();
  }

  testWidgets('actual Edit Profile screen switches English to Tamil', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpProfile(tester);

    for (final label in [
      'Edit Profile',
      'Tap to change photo',
      'Full Name',
      'Enter your name',
      'Email',
      'Enter your email',
      'Phone',
      'Enter your phone',
      'Flat Number',
      'e.g., A-101',
      'Save Changes',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'English label: $label');
    }

    await tester
        .element(find.byType(EditProfileScreen))
        .setLocale(const Locale('ta'));
    await tester.pumpAndSettle();

    for (final label in [
      'சுயவிவரத்தைத் திருத்து',
      'புகைப்படத்தை மாற்ற தட்டவும்',
      'முழுப் பெயர்',
      'உங்கள் பெயரை உள்ளிடவும்',
      'மின்னஞ்சல்',
      'உங்கள் மின்னஞ்சலை உள்ளிடவும்',
      'தொலைபேசி',
      'உங்கள் தொலைபேசி எண்ணை உள்ளிடவும்',
      'வீட்டு எண்',
      'எ.கா., A-101',
      'மாற்றங்களைச் சேமி',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'Tamil label: $label');
    }
    for (final englishLabel in [
      'Edit Profile',
      'Tap to change photo',
      'Full Name',
      'Enter your email',
      'Save Changes',
    ]) {
      expect(find.text(englishLabel), findsNothing);
    }

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'not-an-email');
    await tester.tap(find.text('மாற்றங்களைச் சேமி'));
    await tester.pumpAndSettle();
    expect(find.text('சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo source labels and save/back actions stay functional', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpProfile(tester);

    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    expect(find.text('Select Photo Source'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Take a new photo'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);

    Navigator.of(tester.element(find.text('Select Photo Source'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open edit profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Arabic Edit Profile fits at ${width.toInt()}px with large text',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpProfile(tester, width: width);

        await tester
            .element(find.byType(EditProfileScreen))
            .setLocale(const Locale('ar'));
        await tester.pumpAndSettle();

        final arabicContext = tester.element(find.byType(EditProfileScreen));
        expect(Directionality.of(arabicContext), ui.TextDirection.rtl);
        expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
        expect(find.text('الاسم الكامل'), findsOneWidget);
        expect(find.text('البريد الإلكتروني'), findsOneWidget);
        expect(find.text('حفظ التغييرات'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'width: $width');
      },
    );
  }
}
