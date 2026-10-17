import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_visitor_page_background.dart';

void main() {
  testWidgets('visitor page backdrop supports narrow screens and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: ResidentVisitorPageBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Visitor Management'),
                        SizedBox(height: 20),
                        Text('Awaiting Approval'),
                        Text('A longer visitor purpose that wraps naturally.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visitor Management'), findsOneWidget);
    expect(find.text('Awaiting Approval'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor page backdrop supports Arabic RTL content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ResidentVisitorPageBackground(
              child: const SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إدارة الزوار'),
                        SizedBox(height: 20),
                        Text('بانتظار موافقة الإدارة'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة الزوار'), findsOneWidget);
    expect(find.text('بانتظار موافقة الإدارة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
