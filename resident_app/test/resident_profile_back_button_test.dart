import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:resident_app/src/widgets/resident_profile_back_button.dart';

import 'localization_test_app.dart';

void main() {
  setUpAll(initializeTestLocalization);

  testWidgets('returns to the page that opened Profile', (tester) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: ResidentProfileBackButton()),
                  ),
                ),
                child: const Text('Open Profile'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Profile'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open Profile'), findsOneWidget);
  });

  testWidgets('uses the authenticated Home route when Profile is root', (
    tester,
  ) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const Scaffold(body: ResidentProfileBackButton()),
          onGenerateRoute: (settings) => settings.name == '/home'
              ? MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Home destination')),
                )
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(find.byType(ResidentProfileBackButton), findsNothing);
  });
}
