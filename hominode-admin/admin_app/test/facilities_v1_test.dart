import 'dart:async';

import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/amenity_service.dart';
import 'package:admin_app/services/building_service.dart';
import 'package:admin_app/widgets/add_amenity_modal.dart';
import 'package:admin_app/widgets/edit_amenity_modal.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAdmin implements AdminService {
  String communityId = 'community-a';
  @override
  String requireCurrentCommunityId() => communityId;
  @override
  String getCurrentAdminId() => 'admin-a';
  @override
  Future<Map<String, dynamic>?> getAdminProfile() async => {'name': 'Admin A'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final webFacility = <String, dynamic>{
  'communityId': 'community-a',
  'buildingId': 'building-a',
  'buildingName': 'Tower A',
  'name': 'Fitness room',
  'type': 'Gym',
  'isAvailable': true,
  'isFree': false,
  'pricePerDay': 125.50,
  'description': 'Exercise here',
  'iconName': 'fitness_center',
  'imageUrl': 'https://example.com/gym.png',
  'timeSlots': ['6:00 AM - 7:00 AM', 'Members evening session'],
  'bookingDurations': ['90 minutes', 'Full day'],
  'maxCapacity': 12,
  'allowMultipleBookings': true,
  'hasSubscriptionPackages': true,
  'subscriptionPackages': {'Monthly': 999.50},
  'adminId': 'web-admin',
  'authorName': 'Original author',
  'legacyField': {'keep': true},
};

Future<void> showForm(WidgetTester tester, Widget form) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(800, 1200),
      builder: (_, child) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => form,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> selectFacilityType(WidgetTester tester, String type) async {
  await tapVisible(tester, find.byKey(const ValueKey('facility-type')));
  await tapVisible(tester, find.text(type).last);
}

void main() {
  late FakeFirebaseFirestore db;
  late TestAdmin admin;
  late AmenityService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    admin = TestAdmin();
    service = AmenityService(firestore: db, adminService: admin);
    await db.collection('buildings').doc('building-a').set({
      'communityId': 'community-a',
      'buildingName': 'Tower A',
      'name': 'Old tower name',
    });
    await db.collection('buildings').doc('building-b').set({
      'communityId': 'community-b',
      'name': 'Tower B',
    });
    await db.collection('amenities').doc('web-facility').set(webFacility);
  });

  Future<String> create({
    String building = 'building-a',
    bool available = true,
    bool free = false,
    double? price = 125.50,
  }) => service.addAmenity(
    name: '  Pool  ',
    type: ' Swimming Pool ',
    buildingId: building,
    isAvailable: available,
    isFree: free,
    pricePerDay: price,
  );
  Future<Map<String, dynamic>> saved() async =>
      (await db.collection('amenities').doc('web-facility').get()).data()!;
  Widget editor() => EditAmenityModal(
    amenity: AmenityModel.fromFirestore('web-facility', webFacility),
    amenityService: service,
  );
  Future<void> saveEdit(WidgetTester tester) =>
      tapVisible(tester, find.widgetWithText(ElevatedButton, 'Update Amenity'));

  test(
    'create derives authorized community and building name; canonical defaults',
    () async {
      final id = await create();
      final data = (await db.collection('amenities').doc(id).get()).data()!;
      expect(data, containsPair('communityId', 'community-a'));
      expect(data, containsPair('buildingId', 'building-a'));
      expect(data, containsPair('buildingName', 'Tower A'));
      expect(data, containsPair('name', 'Pool'));
      expect(data, containsPair('type', 'Swimming Pool'));
      expect(data, containsPair('timeSlots', <String>[]));
      expect(data['pricePerDay'], 125.50);
      expect(data['createdAt'], isNotNull);
      expect(data['updatedAt'], isNotNull);
      expect(data['adminId'], 'admin-a');
      expect(data['authorId'], 'admin-a');
    },
  );

  for (final building in ['', ' ', 'missing', 'building-b', 'bad/path']) {
    test(
      'create rejects invalid/deleted/cross-community building "$building"',
      () async {
        await expectLater(
          create(building: building),
          throwsA(anyOf(isA<ArgumentError>(), isA<StateError>())),
        );
        expect((await db.collection('amenities').get()).docs, hasLength(1));
      },
    );
  }
  test('create rejects a building deleted after selection', () async {
    await db.collection('buildings').doc('building-a').delete();
    await expectLater(create(), throwsStateError);
  });
  for (final available in [true, false]) {
    test('create availability $available and free price zero', () async {
      final id = await create(available: available, free: true, price: 400);
      final data = (await db.collection('amenities').doc(id).get()).data()!;
      expect(data['isAvailable'], available);
      expect(data['pricePerDay'], 0);
      expect(data.containsKey('isActive'), isFalse);
    });
  }
  for (final price in [
    -1.0,
    double.nan,
    double.infinity,
    double.negativeInfinity,
  ]) {
    test('reject invalid numeric price $price on create and update', () async {
      await expectLater(create(price: price), throwsArgumentError);
      await expectLater(
        service.updateAmenity('web-facility', {'pricePerDay': price}),
        throwsArgumentError,
      );
    });
  }
  for (final text in ['', 'abc', '-1', 'NaN', 'Infinity']) {
    test('form rejects price text "$text"', () {
      expect(AmenityService.priceValidationError(text), isNotNull);
    });
  }
  test('paid creation requires a price', () async {
    await expectLater(create(price: null), throwsArgumentError);
  });
  test('creates resident-type pricing with owner and tenant fees', () async {
    final id = await service.addAmenity(
      name: 'Swimming Pool',
      type: 'Swimming Pool',
      buildingId: 'building-a',
      isFree: false,
      pricingMode: 'resident_type',
      pricePerDay: 999,
      ownerPricePerDay: 100,
      tenantPricePerDay: 150,
    );

    final data = (await db.collection('amenities').doc(id).get()).data()!;

    expect(data['pricingMode'], 'resident_type');
    expect(data['isFree'], false);
    expect(data['pricePerDay'], 0);
    expect(data['ownerPricePerDay'], 100);
    expect(data['tenantPricePerDay'], 150);
  });

  test('updates a facility to resident-type pricing', () async {
    await service.updateAmenity('web-facility', {
      'pricingMode': 'resident_type',
      'isFree': false,
      'ownerPricePerDay': 120,
      'tenantPricePerDay': 175,
    });

    final data = await saved();

    expect(data['pricingMode'], 'resident_type');
    expect(data['isFree'], false);
    expect(data['pricePerDay'], 0);
    expect(data['ownerPricePerDay'], 120);
    expect(data['tenantPricePerDay'], 175);

    // Existing fields must remain intact.
    expect(data['communityId'], 'community-a');
    expect(data['buildingId'], 'building-a');
    expect(data['legacyField'], {'keep': true});
  });

  test('resident-type pricing requires both owner and tenant fees', () async {
    await expectLater(
      service.addAmenity(
        name: 'Pool',
        type: 'Swimming Pool',
        buildingId: 'building-a',
        isFree: false,
        pricingMode: 'resident_type',
        ownerPricePerDay: 100,
      ),
      throwsArgumentError,
    );

    await expectLater(
      service.addAmenity(
        name: 'Pool',
        type: 'Swimming Pool',
        buildingId: 'building-a',
        isFree: false,
        pricingMode: 'resident_type',
        tenantPricePerDay: 150,
      ),
      throwsArgumentError,
    );
  });
  test('service rejects invalid canonical update types', () async {
    for (final fields in <Map<String, dynamic>>[
      {'pricePerDay': '125'},
      {'isAvailable': 'true'},
      {'isFree': 1},
      {'name': ' '},
      {'type': ''},
      {
        'timeSlots': [' '],
      },
      {
        'timeSlots': [3],
      },
      {'maxCapacity': 0},
      {'imageUrl': 'javascript:alert(1)'},
      {'imageUrl': 'https://'},
    ]) {
      await expectLater(
        service.updateAmenity('web-facility', fields),
        throwsArgumentError,
      );
    }
    expect(await saved(), webFacility);
  });
  test(
    'create validates names, slots, image, capacity and preserves advanced values',
    () async {
      Future<String> advanced({
        String name = 'Pool',
        String type = 'Sports',
        List<String> slots = const [' Custom slot '],
        String? image,
        int capacity = 8,
      }) => service.addAmenity(
        name: name,
        type: type,
        buildingId: 'building-a',
        isFree: true,
        timeSlots: slots,
        imageUrl: image,
        maxCapacity: capacity,
        allowMultipleBookings: true,
        bookingDurations: ['90 minutes'],
        hasSubscriptionPackages: true,
        subscriptionPackages: {'Monthly': 200},
      );
      for (final operation in [
        () => advanced(name: ' '),
        () => advanced(type: ''),
        () => advanced(slots: ['']),
        () => advanced(image: 'not a URL'),
        () => advanced(capacity: 0),
      ]) {
        await expectLater(operation(), throwsArgumentError);
      }
      final id = await advanced(image: 'https://example.com/pool.png');
      final data = (await db.collection('amenities').doc(id).get()).data()!;
      expect(data['maxCapacity'], 8);
      expect(data['bookingDurations'], ['90 minutes']);
      expect(data['subscriptionPackages'], {'Monthly': 200});
      expect(data['timeSlots'], ['Custom slot']);
    },
  );
  test(
    'reject immutable/unknown update fields, including building and community',
    () async {
      for (final key in [
        'communityId',
        'buildingId',
        'buildingName',
        'adminId',
        'isActive',
        'legacyField',
      ]) {
        await expectLater(
          service.updateAmenity('web-facility', {key: 'changed'}),
          throwsArgumentError,
        );
      }
      expect(await saved(), webFacility);
    },
  );
  test('cross-community target rejected for edit and availability', () async {
    admin.communityId = 'community-b';
    await expectLater(
      service.updateAmenity('web-facility', {'name': 'Other'}),
      throwsStateError,
    );
    await expectLater(
      service.updateAmenity('web-facility', {'isAvailable': false}),
      throwsStateError,
    );
    expect(await saved(), webFacility);
  });
  test('missing update target rejected', () async {
    await expectLater(
      service.updateAmenity('missing', {'name': 'Other'}),
      throwsStateError,
    );
  });
  test(
    'availability changes only isAvailable and timestamp; caller map is not mutated',
    () async {
      final input = {'isAvailable': false};
      await service.updateAmenity('web-facility', input);
      final data = await saved();
      expect(data.remove('updatedAt'), isNotNull);
      expect(data, {...webFacility, 'isAvailable': false});
      expect(input, {'isAvailable': false});
    },
  );
  test(
    'pricing changes normalize free and retain exact paid decimals',
    () async {
      await service.updateAmenity('web-facility', {'isFree': true});
      expect((await saved())['pricePerDay'], 0);
      await service.updateAmenity('web-facility', {
        'isFree': false,
        'pricePerDay': 125.50,
      });
      expect((await saved())['pricePerDay'], 125.50);
    },
  );

  testWidgets(
    'Web arbitrary type opens; name-only edit preserves every other field',
    (tester) async {
      await showForm(tester, editor());
      expect(tester.takeException(), isNull);
      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('125.5'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.byKey(const ValueKey('facility-type-custom')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('facility-name')),
        'Renamed room',
      );
      // Simulate a concurrent advanced/price edit; a name-only form must not clobber it.
      await db.collection('amenities').doc('web-facility').update({
        'maxCapacity': 20,
      });
      await saveEdit(tester);
      final data = await saved();
      expect(data.remove('updatedAt'), isNotNull);
      expect(data, {...webFacility, 'name': 'Renamed room', 'maxCapacity': 20});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('custom slot can be individually removed while presets survive', (
    tester,
  ) async {
    await showForm(tester, editor());
    final chip = find.byKey(const ValueKey('selected-slot-1'));
    await tapVisible(
      tester,
      find.descendant(of: chip, matching: find.byTooltip('Delete')),
    );
    await saveEdit(tester);
    expect((await saved())['timeSlots'], ['6:00 AM - 7:00 AM']);
  });
  testWidgets('adding custom slot and presets preserves existing Web slots', (
    tester,
  ) async {
    await showForm(tester, editor());
    final input = find.byKey(const ValueKey('custom-time-slot'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '  Late evening  ');
    await tapVisible(tester, find.byTooltip('Add time slot'));
    await tapVisible(tester, find.widgetWithText(TextButton, 'All'));
    await saveEdit(tester);
    expect(
      (await saved())['timeSlots'],
      containsAll([
        '6:00 AM - 7:00 AM',
        'Members evening session',
        'Late evening',
      ]),
    );
  });
  testWidgets('image can be edited then cleared without changing building', (
    tester,
  ) async {
    await showForm(tester, editor());
    await tester.enterText(
      find.byKey(const ValueKey('facility-image')),
      'https://example.com/new.png',
    );
    await saveEdit(tester);
    expect((await saved())['imageUrl'], 'https://example.com/new.png');
    await showForm(
      tester,
      EditAmenityModal(
        amenity: AmenityModel.fromFirestore('web-facility', await saved()),
        amenityService: service,
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('facility-image')), '');
    await saveEdit(tester);
    expect((await saved())['imageUrl'], '');
    expect((await saved())['buildingId'], 'building-a');
    expect((await saved())['buildingName'], 'Tower A');
  });
  testWidgets('edit invalid price is rejected without a write', (tester) async {
    await showForm(tester, editor());
    final price = find.byKey(const ValueKey('facility-price'));
    await tester.ensureVisible(price);
    await tester.enterText(price, 'NaN');
    await saveEdit(tester);
    expect(find.text('Enter a finite price of 0 or more'), findsOneWidget);
    expect(await saved(), webFacility);
  });
  testWidgets(
    'Add supports independent type, availability and image; advanced controls retained',
    (tester) async {
      await showForm(
        tester,
        AddAmenityModal(
          amenityService: service,
          buildings: Stream.value([
            BuildingModel(
              id: 'building-a',
              name: 'Untrusted UI name',
              floors: 1,
              flatsPerFloor: 1,
              totalFlats: 1,
              occupied: 0,
              vacant: 1,
              occupancyRate: 0,
            ),
          ]),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('facility-name')),
        'New clubhouse',
      );
      await selectFacilityType(tester, 'Clubhouse');
      await tester.enterText(
        find.byKey(const ValueKey('facility-image')),
        'https://example.com/club.png',
      );
      await tapVisible(
        tester,
        find.widgetWithText(SwitchListTile, 'Available'),
      );
      await tapVisible(
        tester,
        find.widgetWithText(ElevatedButton, 'Add Amenity'),
      );
      final rows = (await db.collection('amenities').get()).docs;
      expect(rows, hasLength(2));
      final data = rows.firstWhere((doc) => doc.id != 'web-facility').data();
      expect(data['type'], 'Clubhouse');
      expect(data['isAvailable'], false);
      expect(data['imageUrl'], 'https://example.com/club.png');
      expect(data['buildingName'], 'Tower A');
      expect(data['timeSlots'], isEmpty);
      expect(data['bookingDurations'], ['1 hour']);
      expect(data['pricePerDay'], 0);
    },
  );

  testWidgets(
    'Edit custom facility type opens Other and preserves it on unrelated edit',
    (tester) async {
      final customFacility = {...webFacility, 'type': 'Yoga Studio'};
      await db.collection('amenities').doc('web-facility').set(customFacility);

      await showForm(
        tester,
        EditAmenityModal(
          amenity: AmenityModel.fromFirestore('web-facility', customFacility),
          amenityService: service,
        ),
      );

      expect(find.text('Other'), findsOneWidget);
      final customType = find.byKey(const ValueKey('facility-type-custom'));
      expect(customType, findsOneWidget);
      expect(
        tester.widget<TextFormField>(customType).controller?.text,
        'Yoga Studio',
      );

      await tester.enterText(
        find.byKey(const ValueKey('facility-name')),
        'Renamed yoga room',
      );
      await saveEdit(tester);

      final data = await saved();
      expect(data['name'], 'Renamed yoga room');
      expect(data['type'], 'Yoga Studio');
    },
  );

  testWidgets('Add Other stores the specified custom facility type', (
    tester,
  ) async {
    await showForm(
      tester,
      AddAmenityModal(
        amenityService: service,
        buildings: Stream.value([
          BuildingModel(
            id: 'building-a',
            name: 'Untrusted UI name',
            floors: 1,
            flatsPerFloor: 1,
            totalFlats: 1,
            occupied: 0,
            vacant: 1,
            occupancyRate: 0,
          ),
        ]),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('facility-name')),
      'Yoga room',
    );
    await selectFacilityType(tester, 'Other');
    await tester.enterText(
      find.byKey(const ValueKey('facility-type-custom')),
      'Yoga Studio',
    );

    await tapVisible(
      tester,
      find.widgetWithText(ElevatedButton, 'Add Amenity'),
    );

    final rows = (await db.collection('amenities').get()).docs;
    expect(rows, hasLength(2));
    final data = rows.firstWhere((doc) => doc.id != 'web-facility').data();
    expect(data['type'], 'Yoga Studio');
  });

  testWidgets('Add creates resident-type pricing with owner and tenant fees', (
    tester,
  ) async {
    await showForm(
      tester,
      AddAmenityModal(
        amenityService: service,
        buildings: Stream.value([
          BuildingModel(
            id: 'building-a',
            name: 'Untrusted UI name',
            floors: 1,
            flatsPerFloor: 1,
            totalFlats: 1,
            occupied: 0,
            vacant: 1,
            occupancyRate: 0,
          ),
        ]),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('facility-name')),
      'Resident type pool',
    );
    await selectFacilityType(tester, 'Swimming Pool');

    await tapVisible(tester, find.text('Chargeable'));
    await tapVisible(tester, find.text('Different fee by resident type'));

    await tester.enterText(
      find.byKey(const ValueKey('facility-owner-price')),
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('facility-tenant-price')),
      '150',
    );

    await tapVisible(
      tester,
      find.widgetWithText(ElevatedButton, 'Add Amenity'),
    );

    final rows = (await db.collection('amenities').get()).docs;
    expect(rows, hasLength(2));
    final data = rows.firstWhere((doc) => doc.id != 'web-facility').data();

    expect(data['pricingMode'], 'resident_type');
    expect(data['isFree'], false);
    expect(data['pricePerDay'], 0);
    expect(data['ownerPricePerDay'], 100);
    expect(data['tenantPricePerDay'], 150);
  });

  testWidgets('Edit loads existing resident-type owner and tenant fees', (
    tester,
  ) async {
    await db.collection('amenities').doc('web-facility').update({
      'pricingMode': 'resident_type',
      'isFree': false,
      'pricePerDay': 0,
      'ownerPricePerDay': 100,
      'tenantPricePerDay': 150,
    });

    final data = await saved();
    await showForm(
      tester,
      EditAmenityModal(
        amenity: AmenityModel.fromFirestore('web-facility', data),
        amenityService: service,
      ),
    );

    expect(find.text('Different fee by resident type'), findsOneWidget);

    final ownerField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('facility-owner-price')),
    );
    final tenantField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('facility-tenant-price')),
    );

    expect(ownerField.controller?.text, '100');
    expect(tenantField.controller?.text, '150');
  });

  testWidgets('Edit saves changed resident-type owner and tenant fees', (
    tester,
  ) async {
    await db.collection('amenities').doc('web-facility').update({
      'pricingMode': 'resident_type',
      'isFree': false,
      'pricePerDay': 0,
      'ownerPricePerDay': 100,
      'tenantPricePerDay': 150,
    });

    final data = await saved();
    await showForm(
      tester,
      EditAmenityModal(
        amenity: AmenityModel.fromFirestore('web-facility', data),
        amenityService: service,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('facility-owner-price')),
      '120.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('facility-tenant-price')),
      '175.75',
    );

    await saveEdit(tester);

    final updated = await saved();
    expect(updated['pricingMode'], 'resident_type');
    expect(updated['isFree'], false);
    expect(updated['pricePerDay'], 0);
    expect(updated['ownerPricePerDay'], 120.5);
    expect(updated['tenantPricePerDay'], 175.75);
  });

  testWidgets(
    'Unrelated edit preserves concurrently changed resident-type pricing',
    (tester) async {
      await db.collection('amenities').doc('web-facility').update({
        'pricingMode': 'resident_type',
        'isFree': false,
        'pricePerDay': 0,
        'ownerPricePerDay': 100,
        'tenantPricePerDay': 150,
      });

      final data = await saved();
      await showForm(
        tester,
        EditAmenityModal(
          amenity: AmenityModel.fromFirestore('web-facility', data),
          amenityService: service,
        ),
      );

      // Simulate another admin changing pricing after this form was opened.
      await db.collection('amenities').doc('web-facility').update({
        'ownerPricePerDay': 130,
        'tenantPricePerDay': 180,
      });

      await tester.enterText(
        find.byKey(const ValueKey('facility-name')),
        'Renamed resident pool',
      );
      await saveEdit(tester);

      final updated = await saved();
      expect(updated['name'], 'Renamed resident pool');
      expect(updated['pricingMode'], 'resident_type');
      expect(updated['isFree'], false);
      expect(updated['pricePerDay'], 0);
      expect(updated['ownerPricePerDay'], 130);
      expect(updated['tenantPricePerDay'], 180);
    },
  );
}
