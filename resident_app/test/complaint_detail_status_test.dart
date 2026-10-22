import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/modals/complaint_detail_modal.dart';
import 'package:resident_app/src/models/complaint.dart';
import 'package:resident_app/src/models/staff_model.dart';

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
      final linkedStaff = StaffModel(
        id: 'staff-1',
        name: 'Linked Technician',
        role: 'maintenance',
        phone: '+1 555 765 4321',
        createdAt: DateTime(2026, 10, 1),
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
                        assignedStaff: linkedStaff,
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
      expect(tester.takeException(), isNull, reason: 'initial detail state');

      expect(tester.widget<StatusBadge>(find.byType(StatusBadge)).label, 'New');
      expect(find.textContaining('Management review'), findsOneWidget);
      expect(find.textContaining('Waiting for staff assignment'), findsNothing);
      expect(find.text('Community support: +1 800 555 0100'), findsOneWidget);
      expect(find.text('Responsible Assignment'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('The gate is stuck.'), findsOneWidget);

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
      expect(tester.takeException(), isNull, reason: 'legacy assignment state');
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
          'status': 'inprogress',
          'assignedTeam': 'maintenance',
          'assignedTo': 'Rahim',
          'progressNotes': [
            {'text': 'Technician is inspecting the entrance.'},
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'manual assignment state');
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Rahim'), findsOneWidget);
      expect(
        find.textContaining('Responsible team: Maintenance · Rahim'),
        findsOneWidget,
      );
      expect(
        find.text('Technician is inspecting the entrance.'),
        findsOneWidget,
      );

      updates.add(
        complaintFromFirestoreData('complaint-1', {
          ...initialData,
          'status': 'inprogress',
          'assignedTeam': 'Management',
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'team-only state');
      expect(find.text('Management'), findsOneWidget);
      expect(find.text('Rahim'), findsNothing);
      expect(find.text('Unassigned'), findsNothing);

      updates.add(
        complaintFromFirestoreData('complaint-1', {
          ...initialData,
          'status': 'inprogress',
          'assignedTeam': 'maintenance',
          'assignedStaffId': 'staff-1',
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'linked staff state');
      expect(find.text('Linked Technician'), findsOneWidget);
      expect(find.textContaining('555'), findsNothing);

      updates.add(
        complaintFromFirestoreData('complaint-1', {
          ...initialData,
          'status': 'completed',
          'resolvedAt': DateTime(2026, 10, 23),
          'resolutionNotes': [
            {'text': 'Gate repaired and tested.'},
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'resolved state');
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).label,
        'Resolved',
      );
      expect(find.text('Gate repaired and tested.'), findsOneWidget);

      // Reopening retains resolvedAt as history while the explicit status wins.
      updates.add(
        complaintFromFirestoreData('complaint-1', {
          ...initialData,
          'status': 'inprogress',
          'resolvedAt': DateTime(2026, 10, 23),
          'assignedTeam': 'maintenance',
          'assignedTo': 'Rahim',
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rahim'), findsOneWidget);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).label,
        'In Progress',
      );
      expect(tester.takeException(), isNull);
      await updates.close();
    },
  );
}
