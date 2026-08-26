import 'package:admin_app/models/pending_resident.dart';
import 'package:admin_app/services/flat_service.dart';
import 'package:admin_app/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'flat occupant compatibility reads matching aliases and fails closed',
    () {
      expect(
        FlatModel.resolveResidentUserId({'residentUid': 'resident-a'}),
        'resident-a',
      );
      expect(
        FlatModel.resolveResidentUserId({
          'residentIds': ['resident-a'],
        }),
        'resident-a',
      );
      expect(
        FlatModel.resolveResidentUserId({
          'residentUserId': 'resident-a',
          'residentUid': 'resident-a',
        }),
        'resident-a',
      );
      expect(
        FlatModel.resolveResidentUserId({
          'residentUserId': 'resident-a',
          'residentUid': 'resident-b',
        }),
        isNull,
      );
      expect(
        FlatModel.resolveResidentUserId({
          'residentUserId': 'resident-a',
          'residentIds': ['resident-b'],
        }),
        isNull,
      );
    },
  );

  test('review requires resident in selected community', () {
    expect(
      ResidentApprovalPolicy.canReview({
        'communityId': 'a',
        'role': 'resident',
      }, 'a'),
      isTrue,
    );
    expect(
      ResidentApprovalPolicy.canReview({
        'communityId': 'b',
        'role': 'resident',
      }, 'a'),
      isFalse,
    );
    expect(
      ResidentApprovalPolicy.canReview({
        'communityId': 'a',
        'role': 'admin',
      }, 'a'),
      isFalse,
    );
  });

  test('canonical assignment must remain inside building community', () {
    expect(
      ResidentApprovalPolicy.canonicalAssignmentMatches(
        building: {'communityId': 'a'},
        unit: {'communityId': 'a', 'buildingId': 'building-1'},
        communityId: 'a',
        buildingId: 'building-1',
      ),
      isTrue,
    );
    expect(
      ResidentApprovalPolicy.canonicalAssignmentMatches(
        building: {'communityId': 'a'},
        unit: {'communityId': 'b', 'buildingId': 'building-1'},
        communityId: 'a',
        buildingId: 'building-1',
      ),
      isFalse,
    );
    expect(
      ResidentApprovalPolicy.canonicalAssignmentMatches(
        building: {'communityId': 'a'},
        unit: {'communityId': 'a', 'buildingId': 'building-2'},
        communityId: 'a',
        buildingId: 'building-1',
      ),
      isFalse,
    );
  });

  test(
    'occupied or maintenance flats cannot be assigned to another resident',
    () {
      expect(
        ResidentApprovalPolicy.flatCanBeAssigned({
          'status': 'vacant',
        }, 'user-1'),
        isTrue,
      );
      expect(
        ResidentApprovalPolicy.flatCanBeAssigned({
          'status': 'occupied',
          'residentUserId': 'user-1',
        }, 'user-1'),
        isTrue,
      );
      expect(
        ResidentApprovalPolicy.flatCanBeAssigned({
          'status': 'occupied',
          'residentUserId': 'user-2',
        }, 'user-1'),
        isFalse,
      );
      expect(
        ResidentApprovalPolicy.flatCanBeAssigned({
          'status': 'maintenance',
        }, 'user-1'),
        isFalse,
      );
    },
  );

  test('pending resident maps canonical registration fields', () {
    final resident = PendingResident.fromMap('uid-1', {
      'fullName': 'Resident Name',
      'phoneNumber': '+919876543210',
      'communityId': 'community-a',
      'buildingReference': 'Tower A',
      'unitReference': 'A101',
      'approvalStatus': 'pending',
      'isActive': false,
      'buildingId': null,
      'flatId': null,
      'unitId': null,
    });
    expect(resident.uid, 'uid-1');
    expect(resident.name, 'Resident Name');
    expect(resident.phoneNumber, '+919876543210');
    expect(resident.buildingReference, 'Tower A');
    expect(resident.unitReference, 'A101');
    expect(resident.approvalStatus, 'pending');
    expect(resident.isActive, isFalse);
  });

  group('pending approval queue eligibility', () {
    Map<String, dynamic> resident({
      String communityId = 'community-a',
      String approvalStatus = 'pending',
      bool isActive = false,
      String creationSource = 'resident_registration',
    }) => {
      'communityId': communityId,
      'role': 'resident',
      'approvalStatus': approvalStatus,
      'isActive': isActive,
      'creationSource': creationSource,
    };

    test('normal pending resident appears', () {
      expect(
        ResidentApprovalPolicy.isPendingForCommunity(resident(), 'community-a'),
        isTrue,
      );
    });

    test('bulk-import-claim pending resident appears', () {
      expect(
        ResidentApprovalPolicy.isPendingForCommunity(
          resident(creationSource: 'admin_bulk_import_claim'),
          'community-a',
        ),
        isTrue,
      );
    });

    test('active resident is excluded', () {
      expect(
        ResidentApprovalPolicy.isPendingForCommunity(
          resident(isActive: true),
          'community-a',
        ),
        isFalse,
      );
    });

    test('approved resident is excluded', () {
      expect(
        ResidentApprovalPolicy.isPendingForCommunity(
          resident(approvalStatus: 'approved'),
          'community-a',
        ),
        isFalse,
      );
    });

    test('other-community resident is excluded', () {
      expect(
        ResidentApprovalPolicy.isPendingForCommunity(
          resident(communityId: 'community-b'),
          'community-a',
        ),
        isFalse,
      );
    });
  });

  test('bulk claim maps canonical building, unit, type, and source fields', () {
    final resident = PendingResident.fromMap('uid-bulk', {
      'name': 'Test Owner1',
      'phoneNumber': '+639171111111',
      'communityId': 'GV-0701',
      'role': 'resident',
      'approvalStatus': 'pending',
      'isActive': false,
      'buildingId': 'building-ivory',
      'buildingName': 'Ivory',
      'flatId': 'flat-i002',
      'flatLabel': 'I002',
      'ownershipType': 'owner',
      'creationSource': 'admin_bulk_import_claim',
    });

    expect(resident.buildingReference, 'Ivory');
    expect(resident.unitReference, 'I002');
    expect(resident.residentType, 'owner');
    expect(resident.creationSource, 'admin_bulk_import_claim');
  });

  group('returning resident selection', () {
    Map<String, dynamic> returning({
      String communityId = 'community-a',
      bool active = false,
      String approvalStatus = 'approved',
      String status = 'inactive',
      String occupancyStatus = 'moved_out',
      String? flatId,
      String residentType = 'owner',
      String ownershipType = 'owner',
    }) => {
      'communityId': communityId,
      'role': 'resident',
      'approvalStatus': approvalStatus,
      'isActive': active,
      'status': status,
      'occupancyStatus': occupancyStatus,
      'flatId': flatId,
      'residentType': residentType,
      'ownershipType': ownershipType,
    };

    test('only canonical moved-out profiles are offered for reassignment', () {
      expect(UserService.isReturningResidentData(returning()), isTrue);
      expect(
        UserService.isReturningResidentData(returning(active: true)),
        isFalse,
      );
      expect(
        UserService.isReturningResidentData(
          returning(occupancyStatus: 'suspended', flatId: 'flat-a'),
        ),
        isFalse,
      );
      expect(
        UserService.isReturningResidentData(
          returning(residentType: 'owner', ownershipType: 'tenant'),
        ),
        isFalse,
      );
      expect(
        UserService.isReturningResidentData(
          returning(approvalStatus: 'pending'),
        ),
        isFalse,
      );
    });
  });
}
