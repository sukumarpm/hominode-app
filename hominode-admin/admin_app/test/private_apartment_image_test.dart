import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:admin_app/widgets/private_apartment_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_storage/hominode_storage.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
);
StorageImageAsset asset([int id = 1, int? size]) => StorageImageAsset.fromMap({
  'assetId': 'a1111111-1111-4111-8111-11111111111$id',
  'provider': 'firebase',
  'bucket': 'demo-images.appspot.com',
  'ownerId': 'a',
  'communityId': 'A',
  'feature': 'apartment',
  'resourceId': 'building',
  'contentType': 'image/png',
  'size': size ?? png.length,
  'state': 'ready',
  'storagePath':
      'private_images/A/a/apartment/a1111111-1111-4111-8111-11111111111$id.png',
  'generation': '7',
  'sha256': 'a' * 64,
});
void main() {
  test(
    'deduplicates reads across rebuilds, expires, and evicts least-recent entry',
    () async {
      var reads = 0;
      var now = DateTime(2026);
      final cache = ApartmentImageCache(
        read: (_) async {
          reads++;
          return png;
        },
        scope: () => 'a/A',
        now: () => now,
      );
      await cache.load(asset());
      await cache.load(asset());
      expect(reads, 1);
      for (final id in [2, 3, 4]) {
        await cache.load(asset(id));
      }
      await cache.load(asset());
      expect(reads, 5);
      now = now.add(const Duration(seconds: 61));
      await cache.load(asset());
      expect(reads, 6);
    },
  );
  test(
    'byte budget evicts large entries independently of entry count',
    () async {
      var reads = 0;
      final bytes = Uint8List(8 * 1024 * 1024);
      final cache = ApartmentImageCache(
        read: (_) async {
          reads++;
          return bytes;
        },
        scope: () => 'a/A',
      );
      for (final id in [1, 2, 3, 1]) {
        await cache.load(asset(id, bytes.length));
      }
      expect(reads, 4);
    },
  );
  test(
    'session/community change clears cache and rejects an in-flight delivery',
    () async {
      String? scope = 'a/A';
      final pending = Completer<Uint8List>();
      var reads = 0;
      final cache = ApartmentImageCache(
        read: (_) {
          reads++;
          return pending.future;
        },
        scope: () => scope,
      );
      final read = cache.load(asset());
      await Future<void>.delayed(Duration.zero);
      scope = 'a/B';
      cache.clear();
      pending.complete(png);
      await expectLater(read, throwsStateError);
      scope = null;
      await expectLater(cache.load(asset()), throwsStateError);
      expect(reads, 1);
    },
  );
  test('serializes reads and retries failures without caching them', () async {
    final pending = Completer<Uint8List>();
    var reads = 0;
    final cache = ApartmentImageCache(
      read: (_) {
        reads++;
        return reads == 1 ? pending.future : Future.value(png);
      },
      scope: () => 'a/A',
    );
    final first = cache.load(asset()), second = cache.load(asset());
    await Future<void>.delayed(Duration.zero);
    expect(reads, 1);
    final failed = expectLater(first, throwsStateError);
    pending.completeError(StateError('Denied'));
    await failed;
    expect(await second, png);
    expect(reads, 2);
  });
  testWidgets(
    'private image loads in place and rebuild does not reread bytes',
    (tester) async {
      final pending = Completer<Uint8List>();
      var reads = 0;
      final cache = ApartmentImageCache(
        read: (_) {
          reads++;
          return pending.future;
        },
        scope: () => 'a/A',
      );
      Widget page() => MaterialApp(
        home: PrivateApartmentImage(asset: asset(), cache: cache),
      );
      await tester.pumpWidget(page());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(png);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(reads, 1);
      await tester.pumpWidget(page());
      await tester.pump();
      expect(reads, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'denied read shows retry rather than endless spinner or public fallback',
    (tester) async {
      var reads = 0;
      final cache = ApartmentImageCache(
        read: (_) async {
          reads++;
          if (reads == 1) throw StateError('Denied');
          return png;
        },
        scope: () => 'a/A',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateApartmentImage(asset: asset(), cache: cache),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry image'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byTooltip('Retry image'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('wrong selected community is rejected before a private read', () async {
    var reads = 0;
    final cache = ApartmentImageCache(
      read: (_) async {
        reads++;
        return png;
      },
      scope: () => 'a/B',
    );
    await expectLater(cache.load(asset()), throwsStateError);
    expect(reads, 0);
  });
  test(
    'expired or evicted visible image reauthorizes without reading bytes again',
    () async {
      var reads = 0, checks = 0;
      var now = DateTime(2026);
      var denied = false;
      final cache = ApartmentImageCache(
        read: (_) async {
          reads++;
          return png;
        },
        revalidate: (_) async {
          checks++;
          if (denied) throw StateError('Access revoked');
        },
        scope: () => 'a/A',
        now: () => now,
      );
      final bytes = await cache.load(asset());
      now = now.add(const Duration(seconds: 61));
      expect(await cache.load(asset()), same(bytes));
      expect(reads, 1);
      expect(checks, 1);
      for (final id in [2, 3, 4]) {
        await cache.load(asset(id));
      }
      expect(await cache.load(asset(), retained: bytes), same(bytes));
      expect(reads, 4);
      expect(checks, 2);
      now = now.add(const Duration(seconds: 61));
      denied = true;
      await expectLater(cache.load(asset(), retained: bytes), throwsStateError);
    },
  );
}
