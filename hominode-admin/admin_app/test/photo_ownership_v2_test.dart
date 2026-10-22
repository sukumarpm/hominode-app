import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_storage/hominode_storage.dart';

void main() {
  const id = 'a1111111-1111-4111-8111-111111111111';
  Map<String, dynamic> ticket(String scope, {bool ready = false}) => {
    'contractVersion': 2,
    'ownershipScope': scope,
    'assetId': id,
    'provider': 'firebase',
    'bucket': 'demo-images.appspot.com',
    'communityId': 'A',
    'ownerId': 'a',
    'feature': 'apartment',
    'resourceId': scope == 'COMMUNITY'
        ? 'A'
        : scope == 'BUILDING'
        ? 'b'
        : 'canonical-unit',
    if (scope != 'COMMUNITY') 'buildingId': 'b',
    if (scope == 'UNIT') 'unitId': 'canonical-unit',
    'contentType': 'image/jpeg',
    'size': 4,
    'state': ready ? 'ready' : 'pending',
    'storagePath': ready
        ? 'private_images/A/a/apartment/$id.jpg'
        : 'apartment_images/A/a/$id.jpg',
    if (ready) ...{'generation': '7', 'sha256': 'a' * 64},
  };
  for (final scope in PhotoOwnership.scopes) {
    test(
      '$scope retains V2 binding and uses the exact existing upload contract',
      () async {
        final pending = ticket(scope), ready = ticket(scope, ready: true);
        final calls = <String>[];
        final client = StorageImageUploadClient(
          currentUid: () => 'a',
          call: (name, data) async {
            calls.add(name);
            if (name == 'prepareStorageImageUpload') {
              expect(data, {
                'feature': 'apartment',
                'contractVersion': 2,
                'ownershipScope': scope,
                'resourceId': pending['resourceId'],
                'contentType': 'image/jpeg',
                'size': 4,
              });
              return pending;
            }
            expect(data, {'assetId': id});
            return ready;
          },
          write: (asset, bytes) async {
            expect(asset.toMap(), pending);
            expect(bytes.length, 4);
          },
        );
        final asset = await client.upload(
          feature: 'apartment',
          ownershipScope: scope,
          resourceId: pending['resourceId'] as String,
          contentType: 'image/jpeg',
          bytes: Uint8List.fromList([255, 216, 255, 217]),
        );
        expect(asset.toMap(), ready);
        expect(calls, [
          'prepareStorageImageUpload',
          'completeStorageImageUpload',
        ]);
        expect(
          PhotoOwnership.matches(
            asset.toMap(),
            'B',
            scope,
            asset.resourceId,
            buildingId: 'b',
          ),
          isFalse,
        );
        expect(
          PhotoOwnership.queryFields(
            'A',
            scope,
            asset.resourceId,
            buildingId: 'b',
          )['resourceId'],
          asset.resourceId,
        );
      },
    );
  }
  test(
    'malformed V2, inferred category and wrong unit/building are rejected',
    () {
      final community = ticket('COMMUNITY');
      for (final patch in [
        {'buildingId': 'b'},
        {'contractVersion': 1},
        {'ownershipScope': 'ALL'},
        {'resourceId': 'b'},
      ]) {
        expect(
          () => StorageImageAsset.fromMap({...community, ...patch}),
          throwsFormatException,
        );
      }
      expect(
        PhotoOwnership.matches(
          {'type': 'Common Area', 'communityId': 'A'},
          'A',
          'COMMUNITY',
          'A',
        ),
        isFalse,
      );
      expect(
        PhotoOwnership.matches(
          ticket('UNIT'),
          'A',
          'UNIT',
          '101',
          buildingId: 'b',
        ),
        isFalse,
      );
      expect(
        PhotoOwnership.matches(
          ticket('UNIT'),
          'A',
          'UNIT',
          'canonical-unit',
          buildingId: 'other',
        ),
        isFalse,
      );
    },
  );
}
