import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/resident_private_images.dart';
import 'package:resident_app/src/services/apartment_images_service.dart';
import 'package:hominode_storage/hominode_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = 'a1111111-1111-4111-8111-111111111111';
  Map<String, dynamic> record(String scope) => {
    'contractVersion': 2,
    'ownershipScope': scope,
    'communityId': 'A',
    'status': 'active',
    'resourceId': scope == 'COMMUNITY'
        ? 'A'
        : scope == 'BUILDING'
        ? 'b'
        : 'unit',
    if (scope != 'COMMUNITY') 'buildingId': 'b',
    if (scope == 'UNIT') 'unitId': 'unit',
    'imageAsset': {
      'contractVersion': 2,
      'ownershipScope': scope,
      'communityId': 'A',
      'ownerId': 'admin',
      'resourceId': scope == 'COMMUNITY'
          ? 'A'
          : scope == 'BUILDING'
          ? 'b'
          : 'unit',
      if (scope != 'COMMUNITY') 'buildingId': 'b',
      if (scope == 'UNIT') 'unitId': 'unit',
      'assetId': id,
      'provider': 'firebase',
      'feature': 'apartment',
      'bucket': 'demo.appspot.com',
      'state': 'ready',
      'generation': '7',
      'sha256': 'a' * 64,
      'size': 4,
      'contentType': 'image/jpeg',
      'storagePath': 'private_images/A/admin/apartment/$id.jpg',
    },
  };
  for (final scope in PhotoOwnership.scopes)
    test('$scope excludes other scopes, resources and tenants', () {
      final rows = [
        record('COMMUNITY'),
        record('BUILDING'),
        record('UNIT'),
        {...record(scope), 'communityId': 'B'},
        {
          'communityId': 'A',
          'status': 'active',
          'imageUrl': 'https://example.invalid/legacy.jpg',
        },
      ];
      final resource = scope == 'COMMUNITY'
          ? 'A'
          : scope == 'BUILDING'
          ? 'b'
          : 'unit';
      expect(
        ApartmentImagesService.scopedReferences(
          rows,
          'A',
          scope,
          resource,
          buildingId: 'b',
        ),
        ['hominode-image:$id'],
      );
      expect(
        ApartmentImagesService.scopedReferences(
          rows,
          'A',
          scope,
          'wrong',
          buildingId: 'b',
        ),
        isEmpty,
      );
    });
  test(
    'legacy URLs remain separate; malformed private records never use legacy URLs',
    () {
      final legacy = {
        'communityId': 'A',
        'status': 'active',
        'imageUrl': 'https://example.invalid/old.jpg',
      };
      expect(
        ApartmentImagesService.communityReferences([
          record('COMMUNITY'),
          legacy,
        ], 'A'),
        [legacy['imageUrl']],
      );
      expect(
        () => ApartmentImagesService.imageReference({
          ...record('COMMUNITY'),
          'imageAsset': null,
          'imageUrl': legacy['imageUrl'],
        }),
        throwsFormatException,
      );
    },
  );
  for (final scope in PhotoOwnership.scopes) {
    test(
      '$scope authorized private display uses readStorageImage and decodes V2 bytes',
      () async {
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
        );
        final asset = {
          ...(record(scope)['imageAsset'] as Map<String, dynamic>),
          'size': bytes.length,
          'contentType': 'image/png',
          'storagePath': 'private_images/A/admin/apartment/$id.png',
        };
        final store = ResidentPrivateImageStore(
          scope: () => 'r/A',
          call: (name, data) async {
            expect(name, 'readStorageImage');
            expect(data['assetId'], id);
            return {
              'asset': asset,
              'assetId': id,
              'generation': '7',
              'size': bytes.length,
              'contentType': 'image/png',
              'base64': base64Encode(bytes),
            };
          },
        );
        final loaded = await store.load('hominode-image:$id');
        expect(loaded.asset.ownershipScope, scope);
        expect(loaded.bytes, bytes);
        store.invalidate();
      },
    );
  }
}
