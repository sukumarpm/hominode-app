import 'package:admin_app/models/pending_resident.dart';
import 'package:admin_app/services/resident_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('approval writes canonical resident state and assignment IDs', () {
    final fields = ResidentService.approvalFields(
      adminId: 'admin-1',
      buildingId: 'building-doc-1',
      flatId: 'flat-doc-1',
      buildingName: 'Tower A',
      flatLabel: 'A101',
      timestamp: 'server-time',
    );
    expect(fields['approvalStatus'], 'approved');
    expect(fields['isActive'], isTrue);
    expect(fields['buildingId'], 'building-doc-1');
    expect(fields['flatId'], 'flat-doc-1');
    expect(fields['unitId'], 'flat-doc-1');
    expect(fields['updatedAt'], 'server-time');
  });

  test('rejection preserves the resident document in rejected state', () {
    final fields = ResidentService.rejectionFields(
      adminId: 'admin-1',
      reason: ' Not a resident ',
      timestamp: 'server-time',
    );
    expect(fields['approvalStatus'], 'rejected');
    expect(fields['isActive'], isFalse);
    expect(fields['rejectedReason'], 'Not a resident');
    expect(fields['updatedAt'], 'server-time');
  });

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
}
