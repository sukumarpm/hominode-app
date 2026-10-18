import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/notice_model.dart';
import 'package:resident_app/src/screens/notifications_screen.dart';

import 'localization_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  testWidgets('opening an actual inbox notice writes its read receipt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026);
    String? marked;
    final notice = NoticeModel(
      id: 'notice',
      title: 'Synthetic notice',
      content: 'Test contents',
      authorId: 'admin',
      authorName: 'Admin',
      publishDate: now,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => localizedMaterialApp(
            context,
            home: NotificationsScreen(
              loadNotifications: () async => [notice],
              markRead: (id) async {
                marked = id;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthetic notice'));
    await tester.pumpAndSettle();
    expect(marked, 'notice');
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Tamil notifications empty state is localized', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      withResidentLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, _) => localizedMaterialApp(
            context,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 760),
                textScaler: TextScaler.linear(1.6),
              ),
              child: const NotificationsScreen(
                loadNotifications: _emptyNotifications,
              ),
            ),
          ),
        ),
        startLocale: const Locale('ta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('அறிவிப்புகள்'), findsOneWidget);
    expect(find.text('அறிவிப்புகள் இல்லை'), findsOneWidget);
    expect(
      find.text('நீங்கள் அனைத்தையும் பார்த்துவிட்டீர்கள்!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<List<NoticeModel>> _emptyNotifications() async => const [];
