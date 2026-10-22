import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/modals/complaint_detail_modal.dart';
import 'package:resident_app/src/models/complaint.dart';

void main() {
  testWidgets(
    'detail follows live workflow statuses and uses only community support contact',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final updates = StreamController<Complaint>();
      final initialData = <String, dynamic>{
        'communityId': 'community-a',
        'title': 'Gate repair',
        'description': 'The gate is stuck.',
        'category': 'security',
        'status': 'pending',
        'createdDate': DateTime(2026, 10, 22).toIso8601String(),
      };
      final initialComplaint = complaintFromFirestoreData(
        'complaint-1',
        initialData,
      );
      updates.add(initialComplaint);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (context, child) => MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const ValueKey('open-resident-complaint'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ComplaintDetailModal(
                        complaint: initialComplaint,
                        complaintUpdates: updates.stream,
                        communitySupportPhoneLoader: (_) async =>
                            '+1 800 555 0100',
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-resident-complaint')));
      await tester.pumpAndSettle();

      expect(tester.widget<StatusBadge>(find.byType(StatusBadge)).label, 'New');
      expect(find.textContaining('Management review'), findsOneWidget);
      expect(find.textContaining('Waiting for staff assignment'), findsNothing);
      expect(find.text('Community support: +1 800 555 0100'), findsOneWidget);

      final privateAssignment = 'Private vendor +1 555 123 4567';
      updates.add(
        complaintFromFirestoreData('complaint-1', {
          ...initialData,
          'status': 'inprogress',
          'assignedTeam': 'security',
          'assignedTo': privateAssignment,
          'technicianPhone': '+1 555 765 4321',
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).label,
        'In Progress',
      );
      expect(find.textContaining('Responsible team: Security'), findsOneWidget);
      expect(find.textContaining('Private vendor'), findsNothing);
      expect(find.textContaining('+1 555 123 4567'), findsNothing);
      expect(find.textContaining('+1 555 765 4321'), findsNothing);

      updates.add(
        complaintFromFirestoreData('complaint-1', {
          ...initialData,
          'status': 'completed',
          'resolvedAt': DateTime(2026, 10, 23),
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).label,
        'Resolved',
      );

      // Reopening retains resolvedAt as history while the explicit status wins.
      updates.add(
        complaintFromFirestoreData('complaint-1', {
          ...initialData,
          'status': 'inprogress',
          'resolvedAt': DateTime(2026, 10, 23),
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).label,
        'In Progress',
      );
      expect(tester.takeException(), isNull);
      await updates.close();
    },
  );
}
