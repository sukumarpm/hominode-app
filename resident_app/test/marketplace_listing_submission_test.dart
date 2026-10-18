import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'package:resident_app/src/screens/marketplace_create_listing_screen.dart';
import 'package:resident_app/src/services/firebase_image_upload_service.dart';
import 'package:resident_app/src/services/listing_firestore_service.dart';
import 'package:resident_app/src/services/resident_image_operations.dart';
import 'resident_image_operations_test.dart' show ticket;

class _Transport extends Fake implements FirebaseImageUploadService {
  Object? draftError;
  bool failUpload = false, loseCommitReply = false;
  Completer<void>? waitForDraft;
  int drafts = 0, uploads = 0, commits = 0;
  final requests = <Map<String, dynamic>>[];
  final listings = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (name == 'createResidentImageDraft') {
      drafts++;
      await waitForDraft?.future;
      if (draftError != null) throw draftError!;
      return {'resourceId': 'owned-draft-$drafts'};
    }
    expect(name, 'commitResidentImages');
    commits++;
    requests.add(Map.of(data));
    listings[data['resourceId'] as String] = Map.of(data);
    if (loseCommitReply) throw StateError('Synthetic lost reply');
    return {
      'resourceId': data['resourceId'],
      'imageRevision': 1,
      'references': data['references'],
    };
  }

  @override
  Future<StorageImageAsset> upload({
    required String feature,
    required String resourceId,
    required String contentType,
    required Uint8List bytes,
    void Function(StorageImageAsset)? onReserved,
    void Function()? onStored,
  }) async {
    uploads++;
    if (failUpload) throw StateError('Synthetic failed upload');
    expect(feature, 'marketplace');
    return ticket(feature, resourceId, ready: true);
  }
}

void main() {
  late _Transport transport;
  late ListingFirestoreService service;
  late Directory directory;
  late File photo;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'marketplace-submission-',
    );
    photo = await File(
      '${directory.path}/photo.jpg',
    ).writeAsBytes([255, 216, 255, 217]);
    transport = _Transport();
    service = ListingFirestoreService(
      currentUid: () => 'resident',
      images: ResidentImageOperations(
        transport: transport,
        currentUid: () => 'resident',
        newOperationId: () => 'same-operation',
      ),
    );
  });
  tearDown(() => directory.delete(recursive: true));
  Future<ServiceResult> submit({bool image = true}) => service.createListing(
    title: 'Chair',
    price: 500,
    category: 'Furniture',
    condition: 'Good',
    description: 'Good condition',
    imagePaths: image ? [photo.path] : [],
  );

  test('selected image finalizes before atomic listing attachment', () async {
    final result = await submit();
    expect(result.success, isTrue);
    expect(result.data, 'owned-draft-1');
    expect(transport.uploads, 1);
    expect(transport.listings.length, 1);
    expect(transport.requests.single['references'], [
      'hominode-image:a1111111-1111-4111-8111-111111111111',
    ]);
    expect(transport.requests.single.keys, isNot(contains('communityId')));
  });
  test(
    'failed upload creates no partial listing; retry reuses draft',
    () async {
      transport.failUpload = true;
      expect((await submit()).success, isFalse);
      expect(transport.listings, isEmpty);
      expect(transport.commits, 0);
      transport.failUpload = false;
      expect((await submit()).success, isTrue);
      expect(transport.drafts, 1);
      expect(transport.listings.length, 1);
    },
  );
  test(
    'lost commit reply retries identical draft, operation and finalized image',
    () async {
      transport.loseCommitReply = true;
      expect((await submit()).success, isFalse);
      transport.loseCommitReply = false;
      expect((await submit()).success, isTrue);
      expect(transport.requests[1], transport.requests[0]);
      expect(transport.drafts, 1);
      expect(transport.uploads, 1);
      expect(transport.listings.length, 1);
    },
  );
  test(
    'concurrent submit cannot reserve a second draft or create a duplicate',
    () async {
      transport.waitForDraft = Completer<void>();
      final first = submit();
      expect((await submit()).success, isFalse);
      transport.waitForDraft!.complete();
      expect((await first).success, isTrue);
      expect(transport.drafts, 1);
      expect(transport.commits, 1);
    },
  );
  for (final code in [
    'permission-denied',
    'failed-precondition',
    'unauthenticated',
    'unavailable',
  ]) {
    test('$code during draft creation uploads and publishes nothing', () async {
      transport.draftError = FirebaseFunctionsException(
        code: code,
        message: code == 'failed-precondition'
            ? 'This community does not have a subscription.'
            : 'Synthetic failure',
      );
      final result = await submit();
      expect(result.success, isFalse);
      expect(transport.uploads, 0);
      expect(transport.listings, isEmpty);
      if (code == 'failed-precondition') {
        expect(result.message, contains('subscription is not configured'));
      }
      if (code == 'permission-denied') {
        expect(result.message, contains('Plus or Pro'));
      }
      expect(result.message, isNot(contains('Synthetic failure')));
    });
  }
  test(
    'text-only listing retries reuse the same draft after a lost reply',
    () async {
      transport.loseCommitReply = true;
      expect((await submit(image: false)).success, isFalse);
      transport.loseCommitReply = false;
      expect((await submit(image: false)).success, isTrue);
      expect(transport.drafts, 1);
      expect(transport.requests[0], transport.requests[1]);
    },
  );
  testWidgets(
    'denied creation keeps form and allows retry after configuration is restored',
    (tester) async {
      transport.draftError = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'This community does not have a subscription.',
      );
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: MarketplaceCreateListingScreen(listingService: service),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Chair');
      await tester.enterText(find.byType(TextFormField).at(1), '500');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Good condition',
      );
      final button = find.widgetWithText(ElevatedButton, 'Create Listing');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('subscription is not configured'),
        findsOneWidget,
      );
      expect(find.text('Chair'), findsOneWidget);
      expect(transport.listings, isEmpty);
      transport.draftError = null;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(transport.listings.length, 1);
      expect(transport.uploads, 0);
    },
  );
}
