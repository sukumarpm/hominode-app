import 'package:admin_app/models/complaint_models.dart';
import 'package:admin_app/widgets/complaint_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

ComplaintEntry _complaint() => ComplaintEntry(
  id: 'complaint-identifier-that-is-longer-than-a-single-line-on-mobile',
  priority: ComplaintPriority.high,
  status: ComplaintStatus.inProgress,
  title: 'Water leakage in the common corridor',
  residentName: 'A very long resident name for a narrow device',
  unit: 'Tower C, Unit 1204',
  date: DateTime(2026, 10, 22),
  category: ComplaintCategory.plumbing,
  assignedTo: 'Maintenance Supervisor with a very long display name',
  assignedTeam: 'maintenance',
);

Widget _app({required double textScale}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  builder: (context, child) => MaterialApp(
    home: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 288,
            child: SingleChildScrollView(
              child: ComplaintListCard(complaint: _complaint()),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final textScale in [1.0, 1.8]) {
    testWidgets('complaint card fits narrow width at text scale $textScale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(textScale: textScale));
      await tester.pump();

      expect(find.text('High'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Water leakage in the common corridor'), findsOneWidget);
      expect(find.text('Resident'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('Reported'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Responsible'), findsOneWidget);
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.textContaining('Maintenance Supervisor'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data?.startsWith('#complaint-identifier') == true &&
              widget.maxLines == 1 &&
              widget.overflow == TextOverflow.ellipsis,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unassigned cards keep the same metadata order', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final complaint = ComplaintEntry(
      id: 'c-2',
      priority: ComplaintPriority.low,
      status: ComplaintStatus.pending,
      title: 'Short title',
      residentName: 'Resident',
      unit: 'A-101',
      date: DateTime(2026, 10, 22),
      category: ComplaintCategory.other,
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 288,
                child: SingleChildScrollView(
                  child: ComplaintListCard(complaint: complaint),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final rowTops = [
      'Resident',
      'Unit',
      'Reported',
      'Category',
      'Responsible',
    ].map((label) => tester.getTopLeft(find.text(label).first).dy).toList();
    expect(rowTops, orderedEquals(rowTops.toList()..sort()));
    expect(find.text('Management'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
