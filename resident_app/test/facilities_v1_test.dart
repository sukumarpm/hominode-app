// Read-only test doubles intentionally implement Firestore interfaces.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';
import 'package:provider/provider.dart';
import 'package:resident_app/src/modals/booking_modal.dart';
import 'package:resident_app/src/models/amenity.dart';
import 'package:resident_app/src/models/booking.dart';
import 'package:resident_app/src/screens/amenities_booking_screen.dart';
import 'package:resident_app/src/services/booking_firestore_service.dart';
import 'package:resident_app/src/services/tenant_resolution_service.dart';
import 'package:resident_app/src/widgets/facility_information.dart';

import 'localization_test_app.dart';

class FixedCommunityTenantResolutionService extends TenantResolutionService {
  FixedCommunityTenantResolutionService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : super(auth: auth, firestore: firestore);

  @override
  String? get communityId => 'community-a';
}

// Read-only Firestore double: records actual query constraints. Any attempted
// write or unsupported operation fails; this does not simulate security rules.
typedef Data = Map<String, dynamic>;

class ReadStore implements FirebaseFirestore {
  final rows = <String, Data>{};
  final queries = <Map<Object, Object?>>[];
  final directReads = <String>[];
  final changes = StreamController<String>.broadcast();
  @override
  CollectionReference<Data> collection(String path) =>
      ReadCollection(this, path);
  void change(String path, Data data) {
    rows[path] = data;
    changes.add(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected Firestore operation: ${invocation.memberName}',
  );
}

class ReadQuery implements Query<Data> {
  ReadQuery(this.store, this.path, [this.filters = const {}]);
  final ReadStore store;
  final String path;
  final Map<Object, Object?> filters;
  @override
  Query<Data> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => ReadQuery(store, path, {...filters, field: isEqualTo});
  @override
  Query<Data> limit(int count) => this;
  ReadSnapshot result() {
    if (path != 'amenities' || filters['communityId'] == null) {
      throw StateError('Unscoped or unexpected query');
    }
    store.queries.add(Map.of(filters));
    return ReadSnapshot(
      store.rows.entries
          .where((row) => row.key.startsWith('$path/'))
          .where(
            (row) => filters.entries.every(
              (filter) =>
                  (filter.key == FieldPath.documentId
                      ? row.key.split('/').last
                      : row.value[filter.key]) ==
                  filter.value,
            ),
          )
          .map((row) => ReadDocument(row.key.split('/').last, row.value))
          .toList(),
    );
  }

  @override
  Future<QuerySnapshot<Data>> get([GetOptions? options]) async => result();
  @override
  Stream<QuerySnapshot<Data>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield result();
    yield* store.changes.stream
        .where((key) => key.startsWith('$path/'))
        .map((_) => result());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected query operation: ${invocation.memberName}');
}

class ReadCollection extends ReadQuery implements CollectionReference<Data> {
  ReadCollection(super.store, super.path);
  @override
  DocumentReference<Data> doc([String? id]) =>
      ReadReference(store, '$path/$id');
}

class ReadReference implements DocumentReference<Data> {
  ReadReference(this.store, this.path);
  final ReadStore store;
  @override
  final String path;
  ReadDocument result() {
    if (!path.startsWith('users/')) {
      throw StateError('Direct facility read is forbidden in this test');
    }
    store.directReads.add(path);
    return ReadDocument(path.split('/').last, store.rows[path]);
  }

  @override
  Future<DocumentSnapshot<Data>> get([GetOptions? options]) async => result();
  @override
  Stream<DocumentSnapshot<Data>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield result();
    yield* store.changes.stream
        .where((key) => key == path)
        .map((_) => result());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected document operation: ${invocation.memberName}',
  );
}

class ReadDocument implements QueryDocumentSnapshot<Data> {
  ReadDocument(this.id, this.value);
  @override
  final String id;
  final Data? value;
  @override
  bool get exists => value != null;
  @override
  Data data() => value ?? {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ReadSnapshot implements QuerySnapshot<Data> {
  ReadSnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Data>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ReadUser implements User {
  @override
  String get uid => 'resident-a';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ReadAuth implements FirebaseAuth {
  @override
  User? currentUser = ReadUser();
  final changes = StreamController<User?>.broadcast();
  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* changes.stream;
  }

  void signOutForTest() {
    currentUser = null;
    changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const canonical = <String, dynamic>{
  'communityId': 'community-a',
  'buildingId': 'other-building-a',
  'buildingName': 'Tower Two',
  'name': 'Wellness Room',
  'type': 'Clubhouse',
  'description': 'A quiet place to relax',
  'iconName': 'fitness_center',
  'imageUrl': 'https://example.com/facility.png',
  'isAvailable': true,
  'isFree': false,
  'pricePerDay': 125.50,
  'maxCapacity': 12,
  'allowMultipleBookings': true,
  'timeSlots': ['9:30 AM - 10:30 AM', 'Evening session'],
  'bookingDurations': ['90 minutes', 'Full day'],
};
const profile = <String, dynamic>{
  'communityId': 'community-a',
  'buildingId': 'building-a',
  'role': 'resident',
  'approvalStatus': 'approved',
  'isActive': true,
};

class ModalService implements BookingFirestoreService {
  ModalService(this.details, {this.slotResults = const {}});
  final Stream<AmenityModel?> details;
  final Map<String, Map<String, dynamic>> slotResults;
  int writes = 0;
  @override
  Stream<List<AmenityModel>> streamAmenitiesRealtime() =>
      details.map((amenity) => amenity == null ? [] : [amenity]);
  @override
  Stream<List<BookingModel>> streamMyBookingsRealtime() => Stream.value([]);
  @override
  Stream<AmenityModel?> streamAmenityDetails(String id) => details;
  @override
  Future<bool> isDateFullyBooked({
    required String amenityId,
    required DateTime date,
  }) async => false;
  @override
  Future<Map<String, dynamic>> checkSlotAvailability({
    required String amenityId,
    required DateTime date,
    required String timeSlot,
    int numberOfPeople = 1,
  }) async => {'available': true};
  @override
  Future<Set<DateTime>> getFullyBookedDates({
    required String amenityId,
    required DateTime startDate,
    required DateTime endDate,
    int numberOfPeople = 1,
  }) async => <DateTime>{};

  @override
  Future<Map<String, Map<String, dynamic>>> getSlotAvailabilityForDate({
    required String amenityId,
    required DateTime date,
    int numberOfPeople = 1,
  }) async => slotResults;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    writes++;
    throw StateError('Unexpected booking operation');
  }
}

Future<void> pumpView(
  WidgetTester tester,
  Widget child, {
  bool settle = true,
  double width = 390,
  double height = 844,
  double textScale = 1,
}) async {
  resetTestLocalizationPreferences();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    withEnglishLocalization(
      (localizationContext) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => localizedMaterialApp(
          localizationContext,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

// Booking availability streams can briefly show an indeterminate progress
// indicator, which intentionally keeps scheduling frames. Pump to a concrete
// state produced by the injected service instead of waiting for animations to
// stop or weakening the state assertion.
Future<void> pumpUntilVisible(WidgetTester tester, Finder expected) async {
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (expected.evaluate().isNotEmpty) return;
  }
  expect(expected, findsOneWidget);
}

Future<void> withFacilityImageHttpClient(Future<void> Function() body) async {
  final originalProvider = debugNetworkImageHttpClientProvider;
  debugNetworkImageHttpClientProvider = () => ImageHttpClient();
  try {
    await body();
  } finally {
    debugNetworkImageHttpClientProvider = originalProvider;
    PaintingBinding.instance.imageCache.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  late ReadStore store;
  late ReadAuth auth;
  late BookingFirestoreService service;
  setUp(() {
    store = ReadStore();
    auth = ReadAuth();
    store.rows.addAll({
      'users/resident-a': Map.of(profile),
      'amenities/a': Map.of(canonical),
      'amenities/b': {...canonical, 'communityId': 'community-b'},
    });
    service = BookingFirestoreService.withDependencies(
      firestore: store,
      auth: auth,
    );
  });
  tearDown(() async {
    await store.changes.close();
    await auth.changes.close();
  });

  Future<void> tapFacilityWithEntitlementLoader(
    WidgetTester tester,
    Future<HominodeEntitlement?> Function(String communityId) loader,
  ) async {
    final bookingService = ModalService(
      Stream.value(AmenityModel.fromMap('a', canonical)),
    );
    await pumpView(
      tester,
      ChangeNotifierProvider<TenantResolutionService>.value(
        value: FixedCommunityTenantResolutionService(
          auth: auth,
          firestore: store,
        ),
        child: AmenitiesBookingScreen(
          bookingService: bookingService,
          entitlementLoader: loader,
        ),
      ),
      settle: false,
    );
    await pumpUntilVisible(tester, find.text('View details & book'));
    await tester.tap(find.text('View details & book'));
    await tester.pumpAndSettle();
    expect(bookingService.writes, 0);
  }

  testWidgets('missing community subscription shows its localized guidance', (
    tester,
  ) async {
    var receivedCommunityId = '';
    await tapFacilityWithEntitlementLoader(tester, (communityId) async {
      receivedCommunityId = communityId;
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'This community does not have a subscription.',
      );
    });

    expect(receivedCommunityId, 'community-a');
    expect(
      find.text(
        'This community subscription is not configured. Please contact your community administrator.',
      ),
      findsOneWidget,
    );
    expect(find.byType(BookingModal), findsNothing);
  });

  testWidgets(
    'valid but noneligible plan retains the plan restriction dialog',
    (tester) async {
      await tapFacilityWithEntitlementLoader(
        tester,
        (communityId) async => HominodeEntitlement(
          communityId: communityId,
          planId: 'essential',
          status: HominodeSubscriptionStatus.active,
          features: const {'facilityBooking': false},
          limits: const {},
        ),
      );

      expect(find.text('Facility booking unavailable'), findsOneWidget);
      expect(
        find.text('Facility booking is available with Hominode Plus and Pro.'),
        findsOneWidget,
      );
      expect(find.byType(BookingModal), findsNothing);
    },
  );

  testWidgets('unexpected entitlement error keeps the generic retry message', (
    tester,
  ) async {
    await tapFacilityWithEntitlementLoader(tester, (communityId) async {
      throw StateError('temporary entitlement service error');
    });

    expect(
      find.text(
        'Facility booking access could not be verified. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('subscription is not configured'), findsNothing);
    expect(find.byType(BookingModal), findsNothing);
  });

  test(
    'main read is community-scoped, includes other buildings and excludes other tenants',
    () async {
      final items = await service.streamAmenitiesRealtime().firstWhere(
        (items) => items.isNotEmpty,
      );
      expect(items.map((item) => item.id), ['a']);
      expect(items.single.buildingId, 'other-building-a');
      expect(store.queries, [
        {'communityId': 'community-a'},
      ]);
      expect(store.directReads, ['users/resident-a']);
    },
  );
  for (final value in [null, '', ' ', 99]) {
    test(
      'missing/malformed community $value never broadens facility reads',
      () async {
        store.rows['users/resident-a'] = {...profile, 'communityId': value};
        final events = <List<AmenityModel>>[];
        final sub = service.streamAmenitiesRealtime().listen(events.add);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(events.every((event) => event.isEmpty), isTrue);
        expect(await service.getAmenityDetails('a'), isNull);
        expect(store.queries, isEmpty);
        await sub.cancel();
      },
    );
  }
  test(
    'unauthenticated and inactive resident issue no facility query',
    () async {
      auth.currentUser = null;
      expect(await service.getAmenityDetails('a'), isNull);
      expect(await service.streamAmenitiesRealtime().first, isEmpty);
      auth.currentUser = ReadUser();
      store.rows['users/resident-a'] = {...profile, 'isActive': false};
      expect(await service.getAmenityDetails('a'), isNull);
      expect(store.queries, isEmpty);
    },
  );
  test(
    'strict availability filters false, missing, null and malformed values',
    () async {
      for (final value in [false, null, 'true', 1, <String>[]]) {
        store.rows['amenities/hidden-$value'] = {
          ...canonical,
          'isAvailable': value,
        };
      }
      store.rows['amenities/missing'] = {...canonical}..remove('isAvailable');
      final items = await service.streamAmenitiesRealtime().firstWhere(
        (items) => items.isNotEmpty,
      );
      expect(items.map((item) => item.id), ['a']);
      for (final key in store.rows.keys.where(
        (key) => key.startsWith('amenities/hidden') || key.endsWith('/missing'),
      )) {
        expect(await service.getAmenityDetails(key.split('/').last), isNull);
      }
    },
  );
  test(
    'direct details enforce scope and availability without a direct cross-tenant read',
    () async {
      expect(
        (await service.getAmenityDetails('a'))!.communityId,
        'community-a',
      );
      expect(await service.getAmenityDetails('b'), isNull);
      expect(await service.getAmenityDetails('missing'), isNull);
      store.rows['amenities/a'] = {...canonical, 'isAvailable': false};
      expect(await service.getAmenityDetails('a'), isNull);
      expect(
        store.queries.every((query) => query['communityId'] == 'community-a'),
        isTrue,
      );
      expect(
        store.directReads.every((path) => path == 'users/resident-a'),
        isTrue,
      );
    },
  );
  test(
    'live details disappear on deactivation, profile community change and signout',
    () async {
      final events = <AmenityModel?>[];
      final sub = service.streamAmenityDetails('a').listen(events.add);
      Future<void> tick() =>
          Future<void>.delayed(const Duration(milliseconds: 5));
      await tick();
      expect(events.last!.id, 'a');
      store.change('amenities/a', {...canonical, 'isAvailable': false});
      await tick();
      expect(events.last, isNull);
      store.change('amenities/a', Map.of(canonical));
      await tick();
      expect(events.last!.id, 'a');
      store.change('users/resident-a', {
        ...profile,
        'communityId': 'community-b',
      });
      await tick();
      expect(events.last, isNull);
      store.change('users/resident-a', Map.of(profile));
      await tick();
      expect(events.last!.id, 'a');
      auth.signOutForTest();
      await tick();
      expect(events.last, isNull);
      await sub.cancel();
    },
  );
  test(
    'canonical Web/Flutter data retains display metadata and string slots',
    () {
      final amenity = AmenityModel.fromMap('a', canonical);
      expect(amenity.name, 'Wellness Room');
      expect(amenity.type, 'Clubhouse');
      expect(amenity.buildingName, 'Tower Two');
      expect(amenity.description, canonical['description']);
      expect(amenity.imageUrl, canonical['imageUrl']);
      expect(amenity.images, hasLength(1));
      expect(amenity.images.single.url, canonical['imageUrl']);
      expect(amenity.primaryImageUrl, canonical['imageUrl']);
      expect(amenity.timeSlots, canonical['timeSlots']);
      expect(amenity.bookingDurations, canonical['bookingDurations']);
      expect(amenity.maxCapacity, 12);
      expect(amenity.allowMultipleBookings, isTrue);
    },
  );
  test(
    'managed facility images preserve order and override legacy primary',
    () {
      final amenity = AmenityModel.fromMap('a', {
        ...canonical,
        'imageUrl': 'https://example.com/legacy.jpg',
        'images': [
          {
            'url': 'https://example.com/first.jpg',
            'storagePath': 'facility_images/community-a/a/first.jpg',
            'name': 'first.jpg',
          },
          {'url': 'bad'},
          {
            'url': 'https://example.com/second.webp',
            'storagePath': 'facility_images/community-a/a/second.webp',
            'name': 'second.webp',
          },
        ],
      });

      expect(amenity.images.map((image) => image.url).toList(), [
        'https://example.com/first.jpg',
        'https://example.com/second.webp',
      ]);
      expect(amenity.primaryImageUrl, 'https://example.com/first.jpg');
      expect(amenity.imageUrl, 'https://example.com/legacy.jpg');
      expect(amenity.hasMultipleImages, isTrue);
      expect(
        amenity.images.first.storagePath,
        'facility_images/community-a/a/first.jpg',
      );
    },
  );

  test('invalid or absent managed images fall back to legacy imageUrl', () {
    final invalidManaged = AmenityModel.fromMap('a', {
      ...canonical,
      'images': [
        {'url': 'javascript:alert(1)'},
        {'url': ''},
        5,
      ],
    });

    expect(invalidManaged.images, hasLength(1));
    expect(invalidManaged.images.single.url, canonical['imageUrl']);
    expect(invalidManaged.images.single.storagePath, isNull);
    expect(invalidManaged.primaryImageUrl, canonical['imageUrl']);

    final noUsableImage = AmenityModel.fromMap('a', {
      ...canonical,
      'imageUrl': 'bad',
      'images': [
        {'url': 'file:///tmp/a.jpg'},
      ],
    });

    expect(noUsableImage.images, isEmpty);
    expect(noUsableImage.primaryImageUrl, isNull);
  });

  test('managed facility gallery is capped at six valid photos', () {
    final amenity = AmenityModel.fromMap('a', {
      ...canonical,
      'images': List.generate(
        8,
        (index) => {
          'url': 'https://example.com/$index.jpg',
          'storagePath': 'facility_images/community-a/a/$index.jpg',
        },
      ),
    });

    expect(amenity.images, hasLength(6));
    expect(amenity.images.first.url, 'https://example.com/0.jpg');
    expect(amenity.images.last.url, 'https://example.com/5.jpg');
  });

  test(
    'malformed optional fields fail per field and retain valid list items',
    () {
      final amenity = AmenityModel.fromMap('a', {
        ...canonical,
        'name': 1,
        'type': [],
        'description': {},
        'buildingName': 4,
        'imageUrl': true,
        'timeSlots': [null, '', '  Evening  ', 5],
        'bookingDurations': [false, '1 hour'],
        'maxCapacity': 'many',
        'isFree': 'true',
        'allowMultipleBookings': 'true',
        'subscriptionPackages': {'Monthly': 99.50, 'Bad': '100'},
      });
      expect(amenity.timeSlots, ['Evening']);
      expect(amenity.bookingDurations, ['1 hour']);
      expect(amenity.hasConfiguredCapacity, isFalse);
      expect(amenity.maxCapacity, 1);
      expect(amenity.description, isNull);
      expect(amenity.isFree, isFalse);
      expect(amenity.imageUrl, isNull);
      expect(amenity.subscriptionPackages, {'Monthly': 99.50});
    },
  );
  for (final value in [1, 1.0, 12, 12.0]) {
    test('numeric capacity $value parses safely', () {
      final amenity = AmenityModel.fromMap('a', {
        ...canonical,
        'maxCapacity': value,
      });
      expect(amenity.maxCapacity, value.toInt());
      expect(amenity.hasConfiguredCapacity, isTrue);
    });
  }
  for (final value in [-1, double.nan, double.infinity, '125.50', null]) {
    test('invalid paid price $value is never free', () {
      expect(
        AmenityModel.fromMap('a', {
          ...canonical,
          'pricePerDay': value,
        }).priceDisplay,
        'Price unavailable',
      );
    });
  }
  test(
    'free wins over stale price; paid prices retain integer and decimal amounts',
    () {
      expect(
        AmenityModel.fromMap('a', {...canonical, 'isFree': true}).priceDisplay,
        'Free',
      );
      expect(AmenityModel.fromMap('a', canonical).priceDisplay, '₹125.50/day');
      expect(
        AmenityModel.fromMap('a', {
          ...canonical,
          'pricePerDay': 125,
        }).priceDisplay,
        '₹125/day',
      );
    },
  );
  test('explicit free and flat pricing modes render canonically', () {
    expect(
      AmenityModel.fromMap('a', {
        ...canonical,
        'pricingMode': 'free',
        'isFree': true,
        'pricePerDay': 0,
      }).priceDisplay,
      'Free',
    );
    expect(
      AmenityModel.fromMap('a', {
        ...canonical,
        'pricingMode': 'flat',
        'isFree': false,
        'pricePerDay': 275.50,
      }).priceDisplay,
      '₹275.50/day',
    );
  });

  test('resident-type pricing shows the correct owner or tenant fee', () {
    final data = {
      ...canonical,
      'pricingMode': 'resident_type',
      'isFree': false,
      'pricePerDay': 0,
      'ownerPricePerDay': 100,
      'tenantPricePerDay': 150,
    };

    expect(
      AmenityModel.fromMap('a', data, residentType: 'owner').priceDisplay,
      '₹100/day',
    );
    expect(
      AmenityModel.fromMap('a', data, residentType: 'tenant').priceDisplay,
      '₹150/day',
    );
  });

  test(
    'resident-type pricing fails closed and never falls back to pricePerDay',
    () {
      final data = {
        ...canonical,
        'pricingMode': 'resident_type',
        'isFree': false,
        'pricePerDay': 999,
        'ownerPricePerDay': 100,
        'tenantPricePerDay': 150,
      };

      for (final residentType in <String?>[null, '', 'guest']) {
        expect(
          AmenityModel.fromMap(
            'a',
            data,
            residentType: residentType,
          ).priceDisplay,
          'Price unavailable',
        );
      }

      expect(
        AmenityModel.fromMap('a', {
          ...data,
          'pricePerDay': 0,
          'ownerPricePerDay': null,
        }, residentType: 'owner').priceDisplay,
        'Price unavailable',
      );
      expect(
        AmenityModel.fromMap('a', {
          ...data,
          'pricePerDay': 0,
          'tenantPricePerDay': null,
        }, residentType: 'tenant').priceDisplay,
        'Price unavailable',
      );
    },
  );

  test('unknown explicit pricing mode fails closed', () {
    expect(
      AmenityModel.fromMap('a', {
        ...canonical,
        'pricingMode': 'future_mode',
      }, residentType: 'owner').priceDisplay,
      'Price unavailable',
    );
  });

  test('service applies canonical resident type to facility pricing', () async {
    store.rows['users/resident-a'] = {
      ...profile,
      'residentType': 'owner',
      'ownershipType': 'owner',
    };
    store.rows['amenities/a'] = {
      ...canonical,
      'pricingMode': 'resident_type',
      'isFree': false,
      'pricePerDay': 0,
      'ownerPricePerDay': 100,
      'tenantPricePerDay': 150,
    };

    final owner = await service.streamAmenitiesRealtime().firstWhere(
      (items) => items.isNotEmpty,
    );
    expect(owner.single.priceDisplay, '₹100/day');

    store.rows['users/resident-a'] = {
      ...profile,
      'residentType': 'tenant',
      'ownershipType': 'tenant',
    };
    final tenant = await service.getAmenityDetails('a');
    expect(tenant!.priceDisplay, '₹150/day');
  });

  test('service fails closed for mismatched resident classification', () async {
    store.rows['users/resident-a'] = {
      ...profile,
      'residentType': 'owner',
      'ownershipType': 'tenant',
    };
    store.rows['amenities/a'] = {
      ...canonical,
      'pricingMode': 'resident_type',
      'isFree': false,
      'pricePerDay': 0,
      'ownerPricePerDay': 100,
      'tenantPricePerDay': 150,
    };

    final amenity = await service.getAmenityDetails('a');
    expect(amenity!.priceDisplay, 'Price unavailable');
  });

  test(
    'safe URL and icon mappings include fitness_center and generic fallback',
    () {
      for (final value in [
        null,
        '',
        'bad',
        'javascript:alert(1)',
        'file:///tmp/a',
        'https://',
      ]) {
        expect(AmenityModel.safeImageUrl(value), isNull);
      }
      expect(facilityIcon('fitness_center'), Icons.fitness_center);
      expect(facilityIcon('pool'), Icons.pool);
      expect(facilityIcon('unknown'), Icons.apartment);
    },
  );
  testWidgets(
    'card renders building, description and exact paid price on a mobile grid',
    (tester) async {
      final amenity = AmenityModel.fromMap('a', {
        ...canonical,
        'imageUrl': null,
      });
      await pumpView(
        tester,
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AmenityCard(amenity: amenity),
          ),
        ),
        width: 320,
        textScale: 1.35,
      );
      expect(find.text('Tower Two'), findsOneWidget);
      expect(find.text('A quiet place to relax'), findsOneWidget);
      expect(find.text('₹125.50/day'), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(FacilityImage)).height,
        lessThanOrEqualTo(140),
      );
    },
  );
  testWidgets('no-photo facility uses the approved architectural fallback', (
    tester,
  ) async {
    final amenity = AmenityModel.fromMap('a', {
      ...canonical,
      'imageUrl': null,
      'images': const [],
    });
    await pumpView(tester, FacilityImage(amenity: amenity, height: 132));

    expect(
      find.byKey(const ValueKey('facility-image-fallback')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'booking history card stays readable at narrow width and text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
              child: Scaffold(
                backgroundColor: const Color(0xFFF4F7FB),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: BookingCard(
                    booking: BookingModel(
                      amenityId: 'pool',
                      amenityName: 'Community Swimming Pool',
                      date: DateTime(2026, 10, 20),
                      timeSlot: '10:30 AM - 12:00 PM',
                      status: 'confirmed',
                      userId: 'resident-test',
                    ),
                    onCancel: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Community Swimming Pool'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'details render actual slots, durations and capacity without invented hours',
    (tester) async {
      await pumpView(
        tester,
        SingleChildScrollView(
          child: FacilityInformation(
            amenity: AmenityModel.fromMap('a', {
              ...canonical,
              'imageUrl': 'bad',
            }),
          ),
        ),
      );
      expect(find.text('Building: Tower Two'), findsOneWidget);
      expect(find.text('9:30 AM - 10:30 AM'), findsOneWidget);
      expect(find.text('Evening session'), findsOneWidget);
      expect(
        find.text('Booking durations: 90 minutes, Full day'),
        findsOneWidget,
      );
      expect(find.text('Capacity: 12 people'), findsOneWidget);
      expect(find.textContaining('6:00 AM - 8:00 PM'), findsNothing);
      expect(
        find.byKey(const ValueKey('facility-image-fallback')),
        findsOneWidget,
      );
    },
  );
  testWidgets('multi-image facility renders count and carousel navigation', (
    tester,
  ) async {
    // Keep image completion deterministic and independent of HTTP/network state.
    await withFacilityImageHttpClient(() async {
      final amenity = AmenityModel.fromMap('a', {
        ...canonical,
        'images': [
          {
            'url': 'https://example.com/first.jpg',
            'storagePath': 'facility_images/community-a/a/first.jpg',
          },
          {
            'url': 'https://example.com/second.jpg',
            'storagePath': 'facility_images/community-a/a/second.jpg',
          },
        ],
      });

      await pumpView(tester, FacilityImage(amenity: amenity), settle: false);

      await pumpUntilVisible(tester, find.byType(FacilityImage));
      expect(amenity.images, hasLength(2));
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.byTooltip('Next facility photo'), findsOneWidget);

      await tester.tap(find.byTooltip('Next facility photo'));
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous facility photo'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('valid image is loaded and network failure falls back to icon', (
    tester,
  ) async {
    // Flutter's test HTTP client returns an error; the production errorBuilder must contain it.
    await pumpView(
      tester,
      FacilityImage(amenity: AmenityModel.fromMap('a', canonical)),
    );
    expect(find.byType(Image), findsNWidgets(2));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    expect(
      find.byKey(const ValueKey('facility-image-fallback')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('usable image decodes successfully', (tester) async {
    await withFacilityImageHttpClient(() async {
      await pumpView(
        tester,
        FacilityImage(
          amenity: AmenityModel.fromMap('a', {
            ...canonical,
            'imageUrl': 'https://example.com/success.png',
          }),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final raw = tester.widget<RawImage>(find.byType(RawImage));
      expect(raw.image, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets(
    'modal rejects stale/unavailable details and never invokes booking writes',
    (tester) async {
      final controller = StreamController<AmenityModel?>.broadcast(sync: true);
      final modalService = ModalService(controller.stream);
      final adapter = Amenity(
        id: 'a',
        name: 'Stale name',
        price: 'Stale price',
        isAvailable: true,
        iconName: 'pool',
        backgroundColor: '#fff',
        iconColor: '#000',
      );
      await pumpView(
        tester,
        // The test font (Ahem) makes the existing calendar month heading
        // unusually wide. Test facility widgets at normal scale separately.
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(0.8),
          ),
          child: BookingModal(amenity: adapter, bookingService: modalService),
        ),
        settle: false,
      );
      await pumpUntilVisible(tester, find.byType(BookingModal));
      controller.add(null);
      await pumpUntilVisible(
        tester,
        find.text('This facility is unavailable or no longer exists.'),
      );
      expect(
        find.text('This facility is unavailable or no longer exists.'),
        findsOneWidget,
      );
      expect(find.textContaining('Stale name'), findsNothing);
      expect(find.text('Select Date'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      controller.add(
        AmenityModel.fromMap('a', {
          ...canonical,
          'imageUrl': null,
          'isFree': true,
          'pricingMode': 'free',
          'pricePerDay': 0,
        }),
      );
      // The English locale intentionally renders the translated label as
      // "FREE" (uppercase) in assets/translations/en.json.
      await pumpUntilVisible(tester, find.text('Price: FREE'));
      expect(tester.takeException(), isNull);
      expect(find.text('Price: FREE'), findsOneWidget);
      expect(find.text('Building: Tower Two'), findsOneWidget);
      expect(find.textContaining('6:00 AM - 8:00 PM'), findsNothing);
      controller.add(null);
      await pumpUntilVisible(
        tester,
        find.text('This facility is unavailable or no longer exists.'),
      );
      expect(
        find.text('This facility is unavailable or no longer exists.'),
        findsOneWidget,
      );
      expect(find.text('Select Date'), findsNothing);
      expect(modalService.writes, 0);
      await tester.pumpWidget(const SizedBox());
      unawaited(controller.close());
      await tester.pump();
    },
  );

  test('configured time slots are not represented as live availability', () {
    final amenity = AmenityModel.fromMap('a', canonical);
    expect(amenity.timeSlotsDisplay, '2 configured time slots');
    expect(amenity.timeSlotsDisplay, isNot(contains('available')));
  });

  testWidgets('unverified slot availability fails closed for booking', (
    tester,
  ) async {
    final controller = StreamController<AmenityModel?>.broadcast(sync: true);
    final modalService = ModalService(controller.stream);
    final adapter = Amenity(
      id: 'a',
      name: 'Wellness Room',
      price: '₹125.50/day',
      isAvailable: true,
      iconName: 'pool',
      backgroundColor: '#fff',
      iconColor: '#000',
    );
    await pumpView(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 1600),
          textScaler: TextScaler.linear(0.8),
        ),
        child: BookingModal(amenity: adapter, bookingService: modalService),
      ),
      settle: false,
      height: 1600,
    );
    await pumpUntilVisible(tester, find.byType(BookingModal));
    controller.add(AmenityModel.fromMap('a', canonical));
    await pumpUntilVisible(
      tester,
      find.textContaining('availability could not be verified'),
    );

    expect(
      find.textContaining('availability could not be verified'),
      findsOneWidget,
    );
    final confirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirm Booking'),
    );
    expect(confirm.onPressed, isNull);
    expect(modalService.writes, 0);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });

  testWidgets('verified slot availability enables selection and confirmation', (
    tester,
  ) async {
    final controller = StreamController<AmenityModel?>.broadcast(sync: true);
    final amenity = AmenityModel.fromMap('a', canonical);
    final modalService = ModalService(
      controller.stream,
      slotResults: {
        for (final slot in amenity.timeSlots)
          slot: {'available': true, 'availabilityVerified': true},
      },
    );
    final adapter = Amenity(
      id: 'a',
      name: 'Wellness Room',
      price: '₹125.50/day',
      isAvailable: true,
      iconName: 'pool',
      backgroundColor: '#fff',
      iconColor: '#000',
    );
    await pumpView(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 1600),
          textScaler: TextScaler.linear(0.8),
        ),
        child: BookingModal(amenity: adapter, bookingService: modalService),
      ),
      settle: false,
      height: 1600,
    );
    await pumpUntilVisible(tester, find.byType(BookingModal));
    controller.add(amenity);
    await pumpUntilVisible(tester, find.text(amenity.timeSlots.first));

    await tester.tap(find.text(amenity.timeSlots.first).last);
    await tester.pump(const Duration(milliseconds: 250));
    final confirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirm Booking'),
    );
    expect(confirm.onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Facilities layout is compact at ${width.toInt()}px in RTL', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final facility = AmenityModel.fromMap('a', canonical);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: const TextScaler.linear(1.4),
                ),
                child: AmenitiesBookingScreen(
                  bookingService: ModalService(Stream.value(facility)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      final sectionTop = tester.getTopLeft(find.text('Available Amenities')).dy;
      expect(sectionTop - appBarBottom, lessThan(32));
      expect(tester.takeException(), isNull);
    });
  }
}

class ImageHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => ImageRequest();
  @override
  set autoUncompress(bool value) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ImageRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => ImageResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
