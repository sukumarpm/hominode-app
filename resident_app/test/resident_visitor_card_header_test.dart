import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/resident_visitor_card_header.dart';

void main() {
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
