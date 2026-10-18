import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'package:resident_app/src/services/resident_private_images.dart';
import 'package:resident_app/src/services/apartment_images_service.dart';
import 'package:resident_app/src/services/profile_image_service.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
);
String id(int number) => 'a1111111-1111-4111-8111-11111111111$number';
String ref([int number = 1]) => 'hominode-image:${id(number)}';
Map<String, dynamic> asset([int number = 1, int? size]) => {
  'assetId': id(number),
  'provider': 'firebase',
  'bucket': 'demo-images.appspot.com',
  'ownerId': 'r',
  'communityId': 'A',
  'feature': 'profile',
  'resourceId': 'r',
  'contentType': 'image/png',
  'size': size ?? png.length,
  'state': 'ready',
  'storagePath': 'private_images/A/r/profile/${id(number)}.png',
  'generation': '7',
  'sha256': 'a' * 64,
};
Map<String, dynamic> response([int number = 1]) => {
  'asset': asset(number),
  'assetId': id(number),
  'generation': '7',
  'contentType': 'image/png',
  'size': png.length,
  'base64': base64Encode(png),
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ResidentPrivateImages.install(null));
  test(
    'apartment reader prioritizes private references and leaves historical URLs untouched',
    () {
      expect(
        ApartmentImagesService.imageReference({
          'imageAsset': {
            ...asset(),
            'feature': 'apartment',
            'storagePath': 'private_images/A/r/apartment/${id(1)}.png',
          },
          'imageUrl': 'https://example.invalid/old.jpg',
        }),
        ref(),
      );
      for (final legacy in [
        'https://example.invalid/legacy-cloudinary.jpg',
        'https://example.invalid/firebase?token=synthetic',
      ]) {
        expect(
          ApartmentImagesService.imageReference({'imageUrl': legacy}),
          legacy,
        );
      }
      expect(
        ProfileImageService.fromData({'profileImage': ref()}).imageUrl,
        ref(),
      );
      expect(
        residentImageProvider('https://example.invalid/old.jpg'),
        isA<NetworkImage>(),
      );
    },
  );
  test(
    'authorized private read deduplicates rebuilds and reauthorizes without repeated bytes',
    () async {
      var reads = 0;
      var now = DateTime(2026);
      final store = ResidentPrivateImageStore(
        scope: () => 'r/A',
        now: () => now,
        call: (name, data) async {
          reads++;
          expect(name, 'readStorageImage');
          if (data.containsKey('knownGeneration')) {
            return {...response(), 'base64': null, 'notModified': true};
          }
          return response();
        },
      );
      final first = await store.load(ref());
      expect(await store.load(ref()), same(first));
      expect(reads, 1);
      now = now.add(const Duration(seconds: 61));
      expect((await store.load(ref())).bytes, same(first.bytes));
      expect(reads, 2);
    },
  );
  test(
    'LRU evicts entries; logout or tenant switch rejects stale in-flight bytes',
    () async {
      String? scope = 'r/A';
      var reads = 0;
      final pending = Completer<Map<String, dynamic>>();
      final store = ResidentPrivateImageStore(
        scope: () => scope,
        call: (_, data) async {
          reads++;
          return reads == 1
              ? pending.future
              : response(int.parse((data['assetId'] as String).substring(35)));
        },
      );
      final future = store.load(ref());
      await Future<void>.delayed(Duration.zero);
      scope = null;
      store.invalidate();
      pending.complete(response());
      await expectLater(future, throwsStateError);
      scope = 'r/B';
      store.invalidate();
      await expectLater(store.load(ref()), throwsFormatException);
    },
  );
  test(
    'entry and byte bounds evict rather than retaining every gallery image',
    () async {
      var calls = 0;
      final bytes = List<int>.filled(8 * 1024 * 1024, 0);
      final encoded = base64Encode(bytes);
      final store = ResidentPrivateImageStore(
        scope: () => 'r/A',
        call: (_, data) async {
          calls++;
          final number = int.parse((data['assetId'] as String).substring(35));
          return {
            'asset': asset(number, bytes.length),
            'assetId': id(number),
            'generation': '7',
            'contentType': 'image/png',
            'size': bytes.length,
            'base64': encoded,
          };
        },
      );
      for (final number in [1, 2, 3, 1]) {
        await store.load(ref(number));
      }
      expect(calls, 4);
    },
  );
  test(
    'failed authorization and malformed read data are never cached',
    () async {
      var calls = 0;
      final store = ResidentPrivateImageStore(
        scope: () => 'r/A',
        call: (_, __) async {
          calls++;
          if (calls == 1) {
            throw StateError('Denied');
          }
          if (calls == 2) {
            return {...response(), 'size': 1};
          }
          return response();
        },
      );
      await expectLater(store.load(ref()), throwsStateError);
      await expectLater(store.load(ref()), throwsFormatException);
      expect((await store.load(ref())).bytes, png);
      expect(calls, 3);
    },
  );
  test(
    'profile redirect uses only a server-confirmed current profile reference',
    () async {
      final store = ResidentPrivateImageStore(
        scope: () => 'r/A',
        call: (_, __) async => {...response(2), 'redirectedFrom': id(1)},
      );
      expect((await store.load(ref())).asset.assetId, id(2));
    },
  );
  testWidgets(
    'private provider displays image without network URL or another read during rebuild',
    (tester) async {
      var calls = 0;
      final store = ResidentPrivateImageStore(
        scope: () => 'r/A',
        call: (_, __) async {
          calls++;
          return response();
        },
      );
      ResidentPrivateImages.install(store);
      Widget page() => MaterialApp(
        home: Image(
          image: residentImageProvider(ref()),
          errorBuilder: (_, __, ___) => const Text('Unavailable'),
        ),
      );
      await tester.pumpWidget(page());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNothing);
      final image = tester.widget<RawImage>(find.byType(RawImage));
      expect(image.image?.width, 2);
      expect(calls, 1);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'scope initialization can recover; logout clears a displayed private image',
    (tester) async {
      String? scope;
      var calls = 0;
      final store = ResidentPrivateImageStore(
        scope: () => scope,
        call: (_, __) async {
          calls++;
          return response();
        },
      );
      ResidentPrivateImages.install(store);
      await tester.pumpWidget(
        MaterialApp(
          home: Image(
            image: residentImageProvider(ref()),
            errorBuilder: (_, __, ___) => const Text('Unavailable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      scope = 'r/A';
      store.invalidate();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Unavailable'), findsNothing);
      scope = null;
      store.invalidate();
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'visible decoded image reauthorizes after byte eviction without downloading another buffer',
    () async {
      var calls = 0;
      final store = ResidentPrivateImageStore(
        scope: () => 'r/A',
        call: (_, data) async {
          calls++;
          if (data.containsKey('knownAssetId')) {
            return {...response(), 'base64': null, 'notModified': true};
          }
          return response();
        },
      );
      final known = StorageImageAsset.fromMap(asset());
      final result = await store.load(ref(), knownAsset: known, refresh: true);
      expect(result.bytes, isEmpty);
      expect(calls, 1);
      expect((await store.load(ref())).bytes, png);
      expect(calls, 2);
    },
  );
  test(
    'queued off-screen requests are cancelled before reading more image bytes',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0, needed = true;
      final store = ResidentPrivateImageStore(
        scope: () => 'r/A',
        call: (_, __) async {
          calls++;
          return pending.future;
        },
      );
      final first = store.load(ref());
      final second = store.load(ref(2), stillNeeded: () => needed);
      await Future<void>.delayed(Duration.zero);
      needed = false;
      pending.complete(response());
      await first;
      await expectLater(second, throwsStateError);
      expect(calls, 1);
    },
  );
  testWidgets(
    'background/avatar streams erase protected pixels quietly on logout',
    (tester) async {
      String? scope = 'r/A';
      int? width;
      final store = ResidentPrivateImageStore(
        scope: () => scope,
        call: (_, __) async => response(),
      );
      ResidentPrivateImages.install(store);
      final stream = residentImageProvider(
        ref(),
      ).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, synchronous) {
        width = info.image.width;
        info.dispose();
      });
      stream.addListener(listener);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(width, 2);
      scope = null;
      store.invalidate();
      await tester.pump();
      expect(width, 1);
      expect(tester.takeException(), isNull);
      stream.removeListener(listener);
    },
  );
}
