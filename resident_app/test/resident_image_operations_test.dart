import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'package:resident_app/src/services/firebase_image_upload_service.dart';
import 'package:resident_app/src/services/resident_image_operations.dart';

StorageImageAsset ticket(
  String feature,
  String resource, {
  bool ready = false,
}) => StorageImageAsset.fromMap({
  'assetId': 'a1111111-1111-4111-8111-111111111111',
  'provider': 'firebase',
  'bucket': 'demo-images.appspot.com',
  'ownerId': 'r',
  'communityId': 'A',
  'feature': feature,
  'resourceId': resource,
  'contentType': 'image/jpeg',
  'size': 4,
  'state': ready ? 'ready' : 'pending',
  'storagePath': ready
      ? 'private_images/A/r/$feature/a1111111-1111-4111-8111-111111111111.jpg'
      : 'resident_images/A/r/$feature/a1111111-1111-4111-8111-111111111111.jpg',
  if (ready) ...{'generation': '7', 'sha256': 'a' * 64},
});

class _Transport extends Fake implements FirebaseImageUploadService {
  int writes = 0, completions = 0;
  bool failFinalize = false, failSave = false;
  void Function()? afterWrite;
  final calls = <(String, Map<String, dynamic>)>[];
  @override
  Future<StorageImageAsset> upload({
    required String feature,
    required String resourceId,
    required String contentType,
    required Uint8List bytes,
    void Function(StorageImageAsset)? onReserved,
    void Function()? onStored,
  }) async {
    writes++;
    expect(contentType, 'image/jpeg');
    expect(bytes, [255, 216, 255, 217]);
    onReserved?.call(ticket(feature, resourceId));
    onStored?.call();
    afterWrite?.call();
    if (failFinalize) {
      throw StateError('Unavailable');
    }
    return ticket(feature, resourceId, ready: true);
  }

  @override
  Future<StorageImageAsset> complete(StorageImageAsset asset) async {
    completions++;
    return ticket(asset.feature, asset.resourceId, ready: true);
  }

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add((name, data));
    if (failSave) {
      throw StateError('Lost reply');
    }
    return {
      'resourceId': data['resourceId'] ?? 'owned-draft',
      'imageRevision': (data['expectedRevision'] as int? ?? 0) + 1,
      'references': data['references'] ?? [],
    };
  }
}

void main() {
  late Directory directory;
  late File file;
  late _Transport transport;
  late ResidentImageOperations operations;
  String? uid;
  var operationSequence = 0;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'resident-firebase-contract-',
    );
    file = await File(
      '${directory.path}/photo.jpg',
    ).writeAsBytes([255, 216, 255, 217]);
    transport = _Transport();
    uid = 'r';
    operations = ResidentImageOperations(
      transport: transport,
      newOperationId: () => 'operation-${++operationSequence}',
      currentUid: () => uid,
    );
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  for (final feature in [
    'profile',
    'community_wall',
    'complaints',
    'marketplace',
  ]) {
    test(
      '$feature uses typed Firebase staging and atomic server attachment',
      () async {
        final resource = feature == 'profile' ? 'r' : 'target';
        final ref = await operations.upload(
          feature: feature,
          resourceId: resource,
          imagePath: file.path,
        );
        expect(ref, 'hominode-image:a1111111-1111-4111-8111-111111111111');
        await operations.save(
          feature: feature,
          resourceId: resource,
          revision: 0,
          references: [ref],
        );
        expect(transport.calls.single.$1, 'commitResidentImages');
        expect(transport.calls.single.$2['references'], [ref]);
        expect(transport.calls.single.$2.keys, isNot(contains('communityId')));
        expect(transport.writes, 1);
      },
    );
  }
  test(
    'failed finalization retries the same reservation without another byte upload',
    () async {
      transport.failFinalize = true;
      await expectLater(
        operations.upload(
          feature: 'profile',
          resourceId: 'r',
          imagePath: file.path,
        ),
        throwsStateError,
      );
      expect(transport.calls, isEmpty);
      await operations.upload(
        feature: 'profile',
        resourceId: 'r',
        imagePath: file.path,
      );
      expect(transport.writes, 1);
      expect(transport.completions, 1);
    },
  );
  test(
    'selecting the same file after a confirmed save reserves a new asset',
    () async {
      final ref = await operations.upload(
        feature: 'profile',
        resourceId: 'r',
        imagePath: file.path,
      );
      transport.failSave = true;
      await expectLater(
        operations.save(
          feature: 'profile',
          resourceId: 'r',
          revision: 0,
          references: [ref],
        ),
        throwsStateError,
      );
      await operations.upload(
        feature: 'profile',
        resourceId: 'r',
        imagePath: file.path,
      );
      expect(transport.writes, 1);
      transport.failSave = false;
      await operations.save(
        feature: 'profile',
        resourceId: 'r',
        revision: 0,
        references: [ref],
      );
      await operations.upload(
        feature: 'profile',
        resourceId: 'r',
        imagePath: file.path,
      );
      expect(transport.writes, 2);
    },
  );
  test(
    'failed atomic save retries the same operation and ordered references',
    () async {
      transport.failSave = true;
      await expectLater(
        operations.save(
          feature: 'marketplace',
          resourceId: 'm',
          revision: 3,
          references: ['legacy', 'private'],
        ),
        throwsStateError,
      );
      transport.failSave = false;
      await operations.save(
        feature: 'marketplace',
        resourceId: 'm',
        revision: 4,
        references: ['legacy', 'private'],
      );
      expect(transport.calls[0].$2, transport.calls[1].$2);
    },
  );
  test('owned draft is reused across file and publish retries', () async {
    expect(await operations.createDraft('community_wall'), 'owned-draft');
    expect(await operations.createDraft('community_wall'), 'owned-draft');
    expect(transport.calls.length, 1);
  });
  test(
    'missing or changed session cannot publish a private reference',
    () async {
      uid = null;
      await expectLater(
        operations.upload(
          feature: 'profile',
          resourceId: 'r',
          imagePath: file.path,
        ),
        throwsStateError,
      );
      expect(transport.writes, 0);
      uid = 'r';
      transport.afterWrite = () => uid = 'other';
      await expectLater(
        operations.upload(
          feature: 'profile',
          resourceId: 'r',
          imagePath: file.path,
        ),
        throwsStateError,
      );
      expect(transport.calls, isEmpty);
    },
  );
  test('empty, oversized and unsupported files never reach Firebase', () async {
    for (final bytes in [
      <int>[],
      [1, 2, 3, 4],
    ]) {
      await file.writeAsBytes(bytes);
      await expectLater(
        operations.upload(
          feature: 'profile',
          resourceId: 'r',
          imagePath: file.path,
        ),
        throwsArgumentError,
      );
    }
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(10 * 1024 * 1024 + 1);
    await handle.close();
    await expectLater(
      operations.upload(
        feature: 'profile',
        resourceId: 'r',
        imagePath: file.path,
      ),
      throwsArgumentError,
    );
    expect(transport.writes, 0);
  });
  test(
    'removal and deletion are backend operations with expected revision',
    () async {
      await operations.save(
        feature: 'marketplace',
        resourceId: 'm',
        revision: 2,
        references: [],
        deleteResource: true,
      );
      expect(transport.calls.single.$2['deleteResource'], true);
      expect(transport.calls.single.$2['expectedRevision'], 2);
    },
  );
}
