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
}
