import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_home_due_payment_content.dart';
import 'package:resident_app/src/widgets/resident_home_summary_card.dart';
import 'package:resident_app/src/widgets/resident_home_summary_view_all.dart';

void main() {
  for (final layout in [
    (width: 320.0, scale: 1.0, rtl: false),
    (width: 390.0, scale: 1.0, rtl: false),
    (width: 320.0, scale: 1.7, rtl: false),
    (width: 390.0, scale: 1.7, rtl: true),
  ]) {
    testWidgets(
      'Tamil Home summary labels fit ${layout.width}px at ${layout.scale}x',
      (tester) async {
        tester.view.physicalSize = Size(layout.width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (_, _) => MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(layout.width, 800),
                  textScaler: TextScaler.linear(layout.scale),
                ),
                child: Directionality(
                  textDirection: layout.rtl
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            ResidentHomeSummaryCard(
                              icon: Icons.schedule_rounded,
                              title: 'வரவிருக்கும் பார்வையாளர்',
                              action: 'அனைத்தையும் காண்க',
                              onAction: () {},
                              child: const Text('வருகை எதிர்பார்க்கப்படுகிறது'),
                            ),
                            const SizedBox(height: 12),
                            ResidentHomeSummaryCard(
                              icon: Icons.credit_card_outlined,
                              title: 'செலுத்த வேண்டிய தொகை',
                              action: 'அனைத்தையும் காண்க',
                              onAction: () {},
                              child: ResidentHomeDuePaymentContent(
                                amount: '₹2,850',
                                billTitle: 'தற்போதைய பில் இல்லை',
                                isEmpty: true,
                                viewBillingLabel: 'கட்டண விவரங்களைப் பார்க்க',
                                onViewBilling: () {},
                              ),
                            ),
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

        for (final label in [
          'வரவிருக்கும் பார்வையாளர்',
          'செலுத்த வேண்டிய தொகை',
          'அனைத்தையும் காண்க',
          'கட்டண விவரங்களைப் பார்க்க',
        ]) {
          expect(
            find.text(label),
            label == 'அனைத்தையும் காண்க' ? findsNWidgets(2) : findsOneWidget,
          );
          expect(tester.widget<Text>(find.text(label).first).maxLines, isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final layout in [
    (width: 320.0, scale: 1.0, rtl: false),
    (width: 390.0, scale: 1.0, rtl: false),
    (width: 320.0, scale: 1.7, rtl: false),
    (width: 390.0, scale: 1.7, rtl: true),
    (width: 400.0, scale: 1.0, rtl: false),
  ]) {
    for (final hasData in [false, true]) {
      testWidgets('${hasData ? 'populated' : 'empty'} summary cards fit '
          '${layout.width}px at ${layout.scale}x, rtl=${layout.rtl}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(layout.width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const visitorKey = Key('visitor-summary-card');
        const paymentKey = Key('payment-summary-card');
        final visitorContent = hasData
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Ranjit Kapoor'), Text('Today · 11:30 AM')],
              )
            : const Column(
                children: [
                  Icon(Icons.directions_walk_outlined),
                  Text('No upcoming visitors'),
                ],
              );
        final paymentContent = ResidentHomeDuePaymentContent(
          amount: '₹2,850',
          billTitle: hasData
              ? 'Monthly maintenance charges'
              : 'No current bill',
          isEmpty: !hasData,
          onViewBilling: () {},
        );
        final visitorCard = ResidentHomeSummaryCard(
          key: visitorKey,
          icon: Icons.schedule_rounded,
          title: 'Upcoming Visitor',
          action: 'View all',
          onAction: () {},
          child: visitorContent,
        );
        final dueCard = ResidentHomeSummaryCard(
          key: paymentKey,
          icon: Icons.credit_card_outlined,
          title: 'Due Payment',
          action: 'View all',
          onAction: () {},
          child: paymentContent,
        );

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (context, child) => MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(layout.width, 800),
                  textScaler: TextScaler.linear(layout.scale),
                ),
                child: Directionality(
                  textDirection: layout.rtl
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: layout.width >= 376 && layout.scale <= 1.2
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: visitorCard),
                                    const SizedBox(width: 12),
                                    Expanded(child: dueCard),
                                  ],
                                ),
                              )
                            : Column(children: [visitorCard, dueCard]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('View all'), findsNWidgets(2));
        final viewAllFinder = find.byType(ResidentHomeSummaryViewAll);
        for (var index = 0; index < 2; index++) {
          final actionSize = tester.getSize(viewAllFinder.at(index));
          expect(actionSize.width, 68);
          expect(actionSize.height, 48);
        }
        if (!hasData) {
          expect(find.text('No upcoming visitors'), findsOneWidget);
          expect(find.text('No current bill'), findsOneWidget);
          final compactHeightLimit = layout.scale > 1.2
              ? 240 * layout.scale
              : layout.width >= 376
              ? 250.0
              : 210.0;
          expect(
            tester.getSize(find.byKey(visitorKey)).height,
            lessThan(compactHeightLimit),
          );
          expect(
            tester.getSize(find.byKey(paymentKey)).height,
            lessThan(compactHeightLimit),
          );
        } else {
          expect(find.text('Ranjit Kapoor'), findsOneWidget);
          expect(find.text('Monthly maintenance charges'), findsOneWidget);
        }

        if (layout.width >= 376 && layout.scale <= 1.2) {
          expect(
            tester.getSize(find.byKey(visitorKey)).height,
            closeTo(tester.getSize(find.byKey(paymentKey)).height, 0.1),
          );
          expect(
            tester.getSize(find.text('Upcoming Visitor')).height,
            lessThanOrEqualTo(40),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
