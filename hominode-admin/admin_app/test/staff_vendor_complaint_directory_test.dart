import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/staff_vendor_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _TenantAdminService extends Fake implements AdminService {
  @override
  String? getCurrentAdminId() => 'admin-a';

  @override
  String requireCurrentCommunityId() => 'community-a';
}

void main() {
  test(
    'directory maps only staff and vendors in the selected community',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('staff').doc('staff-a').set({
        'communityId': 'community-a',
        'name': 'Maya Chen',
        'role': 'Maintenance',
        'status': 'active',
        'phone': '+1 555 010 0100',
      });
      await firestore.collection('staff').doc('staff-b').set({
        'communityId': 'community-b',
        'name': 'Other Community Staff',
        'role': 'Security',
        'status': 'active',
      });
      await firestore.collection('vendors').doc('vendor-a').set({
        'communityId': 'community-a',
        'businessName': 'Gate Services',
        'contactPerson': 'Jordan Lee',
        'status': 'active',
      });
      await firestore.collection('vendors').doc('vendor-b').set({
        'communityId': 'community-b',
        'businessName': 'Other Community Vendor',
        'contactPerson': 'Someone Else',
        'status': 'active',
      });
      final service = StaffVendorService(
        firestore: firestore,
        adminService: _TenantAdminService(),
      );

      final staff = await service.getStaffMembers(propagateErrors: true).first;
      final vendors = await service.getVendors(propagateErrors: true).first;

      expect(staff.map((member) => member.name), ['Maya Chen']);
      expect(vendors.map((vendor) => vendor.contactPerson), ['Jordan Lee']);
      expect(staff.single.phone, '+1 555 010 0100');
      // Private contact details remain available in the authorized model but are
      // intentionally not copied by the complaint assignment UI.
    },
  );

  test(
    'new vendors include communityId required by the scoped lookup',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = StaffVendorService(
        firestore: firestore,
        adminService: _TenantAdminService(),
      );

      final vendorId = await service.addVendor(
        businessName: 'Gate Services',
        category: 'Maintenance',
        contactPerson: 'Jordan Lee',
        phone: '+1 555 010 0100',
      );

      final stored = (await firestore.collection('vendors').doc(vendorId).get())
          .data()!;
      expect(stored['communityId'], 'community-a');
      expect(
        (await service.getVendors(propagateErrors: true).first)
            .single
            .businessName,
        'Gate Services',
      );

      final documentedVendorId = await service.addVendorWithDocuments(
        businessName: 'Lift Care',
        category: 'Maintenance',
        contactPerson: 'Alex Morgan',
        phone: '+1 555 010 0111',
        address: 'Service office',
        aadharNumber: 'test-only',
      );
      final documentedVendor =
          (await firestore.collection('vendors').doc(documentedVendorId).get())
              .data()!;
      expect(documentedVendor['communityId'], 'community-a');
    },
  );

  test('directory lookup can preserve Firestore failures for the UI', () async {
    final service = StaffVendorService(
      firestore: FakeFirebaseFirestore(),
      adminService: _TenantAdminService(),
    );

    // A missing community/admin context is surfaced as a failure in complaint
    // assignment mode rather than being represented as a genuinely empty list.
    final noContext = StaffVendorService(
      firestore: FakeFirebaseFirestore(),
      adminService: _NoContextAdminService(),
    );
    await expectLater(
      noContext.getStaffMembers(propagateErrors: true).first,
      throwsStateError,
    );
    expect(await service.getStaffMembers(propagateErrors: true).first, isEmpty);
  });
}

class _NoContextAdminService extends Fake implements AdminService {
  @override
  String? getCurrentAdminId() => null;

  @override
  String requireCurrentCommunityId() => throw StateError('No community');
}
