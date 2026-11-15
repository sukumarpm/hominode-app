import 'dart:async';
import 'package:admin_app/pending_residents_screen.dart';
import 'package:admin_app/models/pending_resident.dart';
import 'package:admin_app/services/building_service.dart';
import 'package:admin_app/services/flat_service.dart';
import 'package:admin_app/services/resident_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/admin_test_localization.dart';

PendingResident resident({
  String status = 'pending',
  String source = 'resident_registration',
  bool active = false,
}) => PendingResident(
  uid: 'resident',
  name: 'Registration Test',
  phoneNumber: '+639171100000',
  communityId: 'A',
  buildingReference: 'Tower A',
  unitReference: '101',
  buildingId: 'building-a',
  flatId: 'flat-a',
  approvalStatus: status,
  isActive: active,
  residentType: 'owner',
  declaredResidentType: 'owner',
  creationSource: source,
);

class _Residents extends Fake implements ResidentService {
  final updates = StreamController<List<PendingResident>>.broadcast();
  List<PendingResident> rows = [resident()];
  int rejections = 0;
  int approvals = 0;
  final pending = Completer<void>();
  Object? error;
  @override
  Stream<List<PendingResident>> watchPendingResidents() async* {
    yield rows;
    yield* updates.stream;
  }

  @override
  Future<void> rejectResident({required String userId, String? reason}) async {
    expect(userId, 'resident');
    rejections++;
    if (error != null) throw error!;
    await pending.future;
    updates.add([]);
  }

  @override
  Future<void> approveResident({
    required String userId,
    required String buildingId,
    required String flatId,
    required String residentType,
  }) async {
    expect(userId, 'resident');
    expect(buildingId, 'building-a');
    expect(flatId, 'flat-a');
    expect(residentType, 'owner');
    approvals++;
    updates.add([]);
  }
}

class _Buildings extends Fake implements BuildingService {
  @override
  Stream<List<BuildingModel>> getBuildings() => Stream.value([
    BuildingModel(
      id: 'building-a',
      name: 'Tower A',
      floors: 1,
      flatsPerFloor: 1,
      totalFlats: 1,
      occupied: 0,
      vacant: 0,
      reserved: 1,
      occupancyRate: 0,
    ),
  ]);
}

class _Flats extends Fake implements FlatService {
  @override
  Stream<List<FlatModel>> getFlatsForBuilding(String buildingId) =>
      Stream.value([
        FlatModel(
          id: 'flat-a',
          flatId: '101',
          buildingId: 'building-a',
          buildingName: 'Tower A',
          floor: 1,
          flatNumber: 1,
          type: '2BHK',
          area: '',
          status: 'reserved',
          reservedOnboardingId: 'matching-onboarding',
        ),
      ]);
}

void main() {
  setUpAll(initializeAdminTestLocalization);
  Future<void> open(WidgetTester tester, _Residents service) async {
    addTearDown(service.updates.close);
    await tester.pumpWidget(
      localizedAdminTestApp(
        PendingResidentsScreen(
          residents: service,
          buildings: _Buildings(),
          flats: _Flats(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pending registration offers distinct approval and final rejection with confirmation',
    (tester) async {
      final service = _Residents();
      await open(tester, service);
      expect(find.text('Approve Registration'), findsOneWidget);
      await tester.ensureVisible(find.text('Reject Registration'));
      await tester.tap(find.text('Reject Registration'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cancels onboarding'), findsOneWidget);
      expect(service.rejections, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.rejections, 0);
      expect(find.text('Registration Test'), findsOneWidget);
    },
  );

  testWidgets(
    'final rejection blocks duplicates, shows processing, refreshes list and reports success',
    (tester) async {
      final service = _Residents();
      await open(tester, service);
      await tester.ensureVisible(find.text('Reject Registration'));
      await tester.tap(find.text('Reject Registration'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      final action = tester.widget<FilledButton>(confirm).onPressed!;
      action();
      action();
      await tester.pump();
      expect(service.rejections, 1);
      expect(find.text('Processing registration...'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      service.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Registration rejected.'), findsOneWidget);
      expect(find.text('Registration Test'), findsNothing);
      expect(service.approvals, 0);
    },
  );

  testWidgets(
    'backend rejection error remains in confirmation and allows retry',
    (tester) async {
      final service = _Residents()
        ..error = StateError('Shared unit ownership conflict');
      await open(tester, service);
      await tester.ensureVisible(find.text('Reject Registration'));
      await tester.tap(find.text('Reject Registration'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Shared unit ownership conflict'),
        findsOneWidget,
      );
      expect(service.rejections, 1);
      service.error = null;
      service.pending.complete();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(service.rejections, 2);
      expect(find.text('Registration rejected.'), findsOneWidget);
    },
  );

  testWidgets(
    'approval uses the residents canonical reserved assignment and updates the live list',
    (tester) async {
      final service = _Residents();
      await open(tester, service);
      await tester.ensureVisible(find.text('Approve Registration'));
      await tester.tap(find.text('Approve Registration'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      final action = tester.widget<FilledButton>(confirm).onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(service.approvals, 1);
      expect(service.rejections, 0);
      expect(find.text('Registration Test'), findsNothing);
    },
  );

  testWidgets(
    'a deleted status excludes pending registration actions even if legacy approval flags remain',
    (tester) async {
      final service = _Residents()
        ..rows = [
          PendingResident.fromMap('resident', {
            'name': 'Deleted Resident',
            'role': 'resident',
            'communityId': 'A',
            'status': 'deleted',
            'approvalStatus': 'pending',
            'isActive': false,
            'creationSource': 'resident_registration',
          }),
        ];
      await open(tester, service);
      expect(find.text('Reject Registration'), findsNothing);
      expect(find.text('Approve Registration'), findsNothing);
      expect(
        ResidentApprovalPolicy.isPendingForCommunity({
          'communityId': 'A',
          'role': 'resident',
          'status': 'deleted',
          'approvalStatus': 'pending',
          'isActive': false,
        }, 'A'),
        false,
      );
    },
  );

  for (final legacy in [false, true]) {
    testWidgets(
      'Admin-created identity-pending registration offers final rejection (legacy=$legacy)',
      (tester) async {
        final service = _Residents()
          ..rows = [
            PendingResident.fromMap('resident', {
              'name': 'Registration Test',
              'role': 'resident',
              'communityId': 'A',
              'creationSource': 'admin_direct',
              'residentType': 'tenant',
              'approvalStatus': legacy ? 'approved' : 'pending',
              'isActive': legacy,
              'identityVerified': false,
              'identityVerificationStatus': 'pending',
              'identityProofStoragePath':
                  'residentIdentityProofs/A/resident/proof.png',
            }),
          ];
        await open(tester, service);
        expect(find.text('Approve Registration'), findsNothing);
        expect(find.text('Review identity proof'), findsOneWidget);
        await tester.ensureVisible(find.text('Reject Registration'));
        await tester.tap(find.text('Reject Registration'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Only this Resident'), findsOneWidget);
        service.pending.complete();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(service.rejections, 1);
        expect(service.approvals, 0);
        expect(find.text('Registration rejected.'), findsOneWidget);
      },
    );
  }

  for (final completed in [false, true]) {
    testWidgets(
      'fully approved Admin-created Resident cannot be finally rejected (completion=$completed)',
      (tester) async {
        final service = _Residents()
          ..rows = [
            PendingResident.fromMap('resident', {
              'role': 'resident',
              'communityId': 'A',
              'creationSource': 'admin_direct',
              'residentType': 'tenant',
              'approvalStatus': 'approved',
              'isActive': true,
              'identityVerified': !completed,
              'identityVerificationStatus': completed ? 'rejected' : 'verified',
              if (completed) 'registrationCompletedAt': DateTime(2026),
            }),
          ];
        await open(tester, service);
        expect(find.text('Reject Registration'), findsNothing);
        expect(find.text('Approve Registration'), findsNothing);
      },
    );
  }

  for (final sample in [
    ('approved', 'resident_registration', true),
    ('approved', 'admin_direct', false),
    ('pending', 'admin_direct', false),
    ('rejected', 'resident_registration', false),
    ('deleted', 'resident_registration', false),
  ]) {
    testWidgets(
      'ineligible optional-owner or legacy fixture ${sample.$1}/${sample.$2} excludes final rejection',
      (tester) async {
        final service = _Residents()
          ..rows = [
            resident(status: sample.$1, source: sample.$2, active: sample.$3),
          ];
        await open(tester, service);
        expect(find.text('Reject Registration'), findsNothing);
        expect(find.text('Approve Registration'), findsNothing);
      },
    );
  }
}
