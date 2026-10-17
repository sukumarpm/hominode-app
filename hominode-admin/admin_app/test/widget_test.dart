import 'package:admin_app/about_hominode_screen.dart';
import 'package:admin_app/theme/hominode_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Hominode About page renders its identity and contact actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          theme: HominodeTheme.light,
          home: const AboutHominodeScreen(),
        ),
      ),
    );

    expect(find.text('About Hominode'), findsOneWidget);
    expect(find.text('HOMINODE'), findsOneWidget);
    expect(find.text('Smart place. Better lives.'), findsOneWidget);
    expect(find.text('Developed by Marantrix.'), findsOneWidget);
    for (final label in ['https://marantrix.com', 'hominodecare@gmail.com']) {
      final action = tester.widget<TextButton>(
        find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
      );
      expect(action.onPressed, isNotNull);
    }
    expect(tester.takeException(), isNull);
  });
}
