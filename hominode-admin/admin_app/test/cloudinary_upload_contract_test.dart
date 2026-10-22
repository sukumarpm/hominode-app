import 'dart:io';
import 'dart:typed_data';
import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/cloudinary_apartment_images_service.dart';
import 'package:admin_app/services/firebase_image_upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'package:http/http.dart' as http;

const assetId = 'a1111111-1111-4111-8111-111111111111';
StorageImageAsset ticket({bool ready = false, String scope = 'BUILDING'}) =>
    StorageImageAsset.fromMap({
      'contractVersion': 2,
      'ownershipScope': scope,
      if (scope == 'BUILDING') 'buildingId': 'building-test',
      'assetId': assetId,
      'provider': 'firebase',
      'bucket': 'demo-images.appspot.com',
      'ownerId': 'a',
      'communityId': 'A',
      'feature': 'apartment',
      'resourceId': scope == 'COMMUNITY' ? 'A' : 'building-test',
      'contentType': 'image/jpeg',
      'size': 4,
      'state': ready ? 'ready' : 'pending',
      'storagePath': ready
          ? 'private_images/A/a/apartment/$assetId.jpg'
          : 'apartment_images/A/a/$assetId.jpg',
      if (ready) ...{'generation': '7', 'sha256': 'a' * 64},
    });

class _Admin extends Fake implements AdminService {
  String? uid = 'a';
  String community = 'A';
  @override
  String? getCurrentAdminId() => uid;
  @override
  String requireCurrentCommunityId() => community;
}

class _Uploads extends Fake implements FirebaseImageUploadService {
  int uploads = 0, completions = 0;
  String scope = 'BUILDING';
  bool failComplete = false, failSave = false, failUpload = false;
  void Function()? afterUpload;
  final calls = <(String, Map<String, dynamic>)>[];
  @override
  Future<StorageImageAsset> upload({
    required String feature,
    required String resourceId,
    required String contentType,
    required Uint8List bytes,
    String? ownershipScope,
    void Function(StorageImageAsset)? onReserved,
    void Function()? onStored,
  }) async {
    uploads++;
    expect(feature, 'apartment');
    expect(ownershipScope, scope);
    expect(resourceId, scope == 'COMMUNITY' ? 'A' : 'building-test');
    expect(contentType, 'image/jpeg');
    onReserved?.call(ticket(scope: scope));
    if (failUpload) throw StateError('Storage failed.');
    onStored?.call();
    afterUpload?.call();
    if (failComplete) throw StateError('Finalization unavailable.');
    return ticket(ready: true, scope: scope);
  }

  @override
  Future<StorageImageAsset> complete(StorageImageAsset reservation) async {
    completions++;
    expect(reservation.assetId, assetId);
    return ticket(ready: true, scope: scope);
  }

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add((name, data));
    if (failSave) throw StateError('Save response lost.');
    return {
      'imageId': data['imageId'] ?? assetId,
      'revision': 1,
      'contractVersion': 2,
      if (name == 'deleteApartmentImage') 'deleted': true,
    };
  }
}

class _NoNetwork extends http.BaseClient {
  int requests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    throw StateError('External upload prohibited.');
  }
}

void main() {
  late Directory temp;
  late File file;
  late _Admin admin;
  late _Uploads uploads;
  late CloudinaryApartmentImagesService service;
  late FakeFirebaseFirestore firestore;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('apartment-firebase-test-');
    file = await File(
      '${temp.path}/photo.jpg',
    ).writeAsBytes([255, 216, 255, 217]);
    admin = _Admin();
    uploads = _Uploads();
    firestore = FakeFirebaseFirestore();
    service = CloudinaryApartmentImagesService(
      firestore: firestore,
      adminService: admin,
      uploads: uploads,
    );
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  Future<String> upload({ApartmentImageModel? replacing}) =>
      service.uploadImage(
        title: 'Courtyard',
        description: 'Garden',
        type: 'Common Area',
        imageFile: file,
        buildingId: 'building-test',
        uploadDate: '17-10-2026',
        uploadTime: '10:00',
        replacing: replacing,
      );
  test(
    'existing upload entry point uses Firebase and server attachment without external HTTP or client metadata writes',
    () async {
      final network = _NoNetwork();
      expect(await http.runWithClient(() => upload(), () => network), assetId);
      expect(network.requests, 0);
      expect(uploads.uploads, 1);
      expect(uploads.calls.single.$1, 'saveApartmentImage');
      expect(uploads.calls.single.$2, {
        'assetId': assetId,
        'title': 'Courtyard',
        'description': 'Garden',
        'type': 'Common Area',
        'uploadDate': '17-10-2026',
        'uploadTime': '10:00',
      });
      expect(
        (await firestore.collection('apartmentImages').get()).docs,
        isEmpty,
      );
    },
  );
  test(
    'failed finalization retries existing staged asset instead of reuploading',
    () async {
      uploads.failComplete = true;
      await expectLater(upload(), throwsStateError);
      expect(uploads.calls, isEmpty);
      expect(uploads.uploads, 1);
      expect(await upload(), assetId);
      expect(uploads.completions, 1);
      expect(uploads.uploads, 1);
    },
  );
  test(
    'lost attachment response retries the same asset and gallery ID',
    () async {
      uploads.failSave = true;
      await expectLater(upload(), throwsStateError);
      uploads.failSave = false;
      expect(await upload(), assetId);
      expect(uploads.uploads, 1);
      expect(uploads.calls[0].$1, uploads.calls[1].$1);
      expect(uploads.calls[0].$2, uploads.calls[1].$2);
    },
  );
  test(
    'Storage failure cannot publish metadata and retry can upload again',
    () async {
      uploads.failUpload = true;
      await expectLater(upload(), throwsStateError);
      expect(uploads.calls, isEmpty);
      uploads.failUpload = false;
      expect(await upload(), assetId);
      expect(uploads.uploads, 2);
    },
  );
  test('community change after upload prevents attachment', () async {
    uploads.afterUpload = () => admin.community = 'B';
    await expectLater(upload(), throwsStateError);
    expect(uploads.calls, isEmpty);
  });
  test('sign-out prevents upload', () async {
    admin.uid = null;
    await expectLater(upload(), throwsStateError);
    expect(uploads.uploads, 0);
  });
  test('unsupported, empty and oversized files never upload', () async {
    await file.writeAsBytes([1, 2, 3, 4]);
    await expectLater(upload(), throwsArgumentError);
    await file.writeAsBytes([]);
    await expectLater(upload(), throwsArgumentError);
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(StorageImageAsset.maxBytes + 1);
    await handle.close();
    await expectLater(upload(), throwsArgumentError);
    expect(uploads.uploads, 0);
  });
  test(
    'replacement sends revision without changing existing title, date or ordering fields',
    () async {
      final model = ApartmentImageModel.fromFirestore('legacy', {
        'buildingId': 'building-test',
        'communityId': 'A',
        'contractVersion': 2,
        'ownershipScope': 'BUILDING',
        'resourceId': 'building-test',
        'revision': 4,
        'title': 'Original',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
        'imageUrl': 'https://example.invalid/legacy.jpg',
      });
      expect(await upload(replacing: model), 'legacy');
      expect(uploads.calls.single.$1, 'saveApartmentImage');
      expect(uploads.calls.single.$2, {
        'assetId': assetId,
        'imageId': 'legacy',
        'expectedRevision': 4,
      });
      expect(model.title, 'Original');
      expect(model.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
    },
  );
  test(
    'deletion calls authorized backend with revision, never deletes a URL',
    () async {
      await service.deleteImage('existing', expectedRevision: 2);
      expect(uploads.calls.single.$1, 'deleteApartmentImage');
      expect(uploads.calls.single.$2, {
        'contractVersion': 2,
        'imageId': 'existing',
        'expectedRevision': 2,
      });
    },
  );
  test(
    'legacy URL and private reference parsing preserve timestamps and order',
    () async {
      final timestamp = Timestamp.fromMillisecondsSinceEpoch(1000);
      await firestore.collection('apartmentImages').doc('old').set({
        'communityId': 'A',
        'imageUrl': 'https://example.invalid/legacy.jpg',
        'createdAt': timestamp,
      });
      await firestore.collection('apartmentImages').doc('new').set({
        'communityId': 'A',
        'imageAsset': (ticket(ready: true).toMap()
          ..remove('contractVersion')
          ..remove('ownershipScope')
          ..remove('buildingId')),
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
      });
      final images = await service.getLegacyImages().first;
      expect(images.map((image) => image.id), ['new', 'old']);
      expect(images.first.imageAsset!.assetId, assetId);
      expect(images.last.imageUrl, 'https://example.invalid/legacy.jpg');
      expect(images.last.imageAsset, isNull);
    },
  );
  test(
    'COMMUNITY upload requires no building and confirms V2 attachment',
    () async {
      uploads.scope = 'COMMUNITY';
      expect(
        await service.uploadImage(
          title: 'Community',
          description: '',
          type: 'Common Area',
          imageFile: file,
          ownershipScope: 'COMMUNITY',
        ),
        assetId,
      );
      expect(uploads.uploads, 1);
    },
  );
  test(
    'community and building queries never include legacy or unit metadata',
    () async {
      await firestore.collection('apartmentImagesV2').doc('community').set({
        'contractVersion': 2,
        'ownershipScope': 'COMMUNITY',
        'communityId': 'A',
        'resourceId': 'A',
        'status': 'active',
      });
      await firestore.collection('apartmentImagesV2').doc('building').set({
        'contractVersion': 2,
        'ownershipScope': 'BUILDING',
        'communityId': 'A',
        'resourceId': 'building-test',
        'buildingId': 'building-test',
        'status': 'active',
      });
      await firestore.collection('apartmentImagesV2').doc('unit').set({
        'contractVersion': 2,
        'ownershipScope': 'UNIT',
        'communityId': 'A',
        'resourceId': 'unit',
        'unitId': 'unit',
        'buildingId': 'building-test',
        'status': 'active',
      });
      await firestore.collection('apartmentImages').doc('legacy').set({
        'communityId': 'A',
        'buildingId': 'building-test',
        'status': 'active',
      });
      expect((await service.getImages().first).map((image) => image.id), [
        'community',
      ]);
      expect(
        (await service.getImagesForBuilding('building-test').first).map(
          (image) => image.id,
        ),
        ['building'],
      );
      expect((await service.getLegacyImages().first).map((image) => image.id), [
        'legacy',
      ]);
    },
  );
  test('legacy replacement is rejected before an upload starts', () async {
    await expectLater(
      upload(
        replacing: ApartmentImageModel.fromFirestore('legacy', {
          'communityId': 'A',
          'buildingId': 'building-test',
        }),
      ),
      throwsStateError,
    );
    expect(uploads.uploads, 0);
  });
}
