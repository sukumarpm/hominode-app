import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/resident_visitor_card_header.dart';

void main() {
  for (final status in ['Rejected', 'Cancelled', 'Revoked', 'مرفوض']) {
    testWidgets(
      'duplicate $status authorization is hidden; badge and timestamp remain',
      (tester) async {
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              home: Scaffold(
                body: ResidentVisitorCardHeader(
                  visitorName: 'Guest',
                  purpose: 'Visit',
                  timeText: 'Today',
                  statusLabel: status,
                  secondaryStatusLabel: status,
                  statusColor: const Color(0xFFDC2626),
                  statusBackgroundColor: const Color(0xFFFFE6EB),
                  rejectedAtLabel: 'Rejected at 10:30 AM',
                ),
              ),
            ),
          ),
        );
        expect(find.text(status), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(status)).style?.color,
          const Color(0xFFDC2626),
        );
        expect(find.text('Rejected at 10:30 AM'), findsOneWidget);
      },
    );
  }
  for (final labels in [
    ['Expected', 'Admin authorized'],
    ['Expected', 'Awaiting Admin approval'],
    ['Checked In', 'Admin authorized'],
  ]) {
    testWidgets('${labels.join(' + ')} retains distinct authorization', (
      tester,
    ) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: ResidentVisitorCardHeader(
                visitorName: 'Guest',
                purpose: 'Visit',
                timeText: 'Today',
                statusLabel: labels[0],
                secondaryStatusLabel: labels[1],
              ),
            ),
          ),
        ),
      );
      expect(find.text(labels[0]), findsOneWidget);
      expect(find.text(labels[1]), findsOneWidget);
    });
  }
  testWidgets('visitor card details wrap at narrow width with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 205,
                  child: const SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: ResidentVisitorCardHeader(
                        visitorName: 'Kimberly Visitor Name',
                        purpose: 'Family visit',
                        timeText: '11:45 PM Today, 11 October',
                        phoneNumber: '+639171234567',
                        statusLabel: 'Pendiente de aprobación',
                        statusColor: Color(0xFFE11D48),
                        statusBackgroundColor: Color(0xFFFFE6EB),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Kimberly Visitor Name'), findsOneWidget);
    expect(find.text('+639171234567'), findsOneWidget);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor card details render at reported narrow detail width', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 205.7,
                child: const ResidentVisitorCardHeader(
                  visitorName: 'Kim',
                  purpose: 'Visit',
                  timeText: '11:45 PM Today',
                  phoneNumber: '+639171234567',
                  statusLabel: 'Awaiting Approval',
                  statusColor: Color(0xFFE11D48),
                  statusBackgroundColor: Color(0xFFFFE6EB),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor details wrap in Arabic RTL with enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 205,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: ResidentVisitorCardHeader(
                        visitorName: 'محمد عبد الرحمن الطويل',
                        purpose: 'زيارة عائلية إلى الوحدة السكنية',
                        timeText: 'اليوم الساعة ١١:٤٥ مساءً',
                        phoneNumber: '+639171234567',
                        statusLabel: 'بانتظار موافقة الإدارة',
                        statusColor: Color(0xFFE11D48),
                        statusBackgroundColor: Color(0xFFFFE6EB),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('محمد عبد الرحمن الطويل'), findsOneWidget);
    expect(find.text('بانتظار موافقة الإدارة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
