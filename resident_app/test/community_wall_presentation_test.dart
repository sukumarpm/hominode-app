import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/post_card.dart';
import 'package:resident_app/src/models/post.dart';

void main() {
  testWidgets('community post card remains readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.7),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                backgroundColor: const Color(0xFFF4F7FB),
                body: SingleChildScrollView(
                  child: PostCard(
                    post: Post(
                      id: 'post-1',
                      authorName: 'مقيم المجتمع',
                      profileImage: '',
                      flat: 'A-101',
                      timeAgo: 'الآن',
                      content:
                          'تحديث للمجتمع مع نص طويل بما يكفي للالتفاف بوضوح على شاشة هاتف ضيقة.',
                      likes: 3,
                      comments: 2,
                    ),
                    onLikePressed: () {},
                    onCommentPressed: () {},
                    onSharePressed: () {},
                    onMenuPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('مقيم المجتمع'), findsOneWidget);
    expect(
      find.text(
        'تحديث للمجتمع مع نص طويل بما يكفي للالتفاف بوضوح على شاشة هاتف ضيقة.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
