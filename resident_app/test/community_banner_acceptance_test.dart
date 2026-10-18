import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/apartment_images_service.dart';
import 'package:resident_app/src/widgets/community_image_slideshow.dart';

void main() {
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
    ),
  );
  test(
    'Admin gallery records are community-scoped, active, ordered and legacy-compatible',
    () {
      expect(
        ApartmentImagesService.communityReferences([
          {
            'communityId': 'A',
            'status': 'active',
            'buildingId': 'other-building',
            'imageUrl': 'https://example.invalid/new.jpg',
            'createdAt': Timestamp(20, 0),
          },
          {
            'communityId': 'A',
            'status': 'active',
            'imageUrl': 'https://example.invalid/old.jpg',
            'createdAt': Timestamp(10, 0),
          },
          {
            'communityId': 'B',
            'status': 'active',
            'imageUrl': 'https://example.invalid/foreign.jpg',
          },
          {
            'communityId': 'A',
            'status': 'deleted',
            'imageUrl': 'https://example.invalid/deleted.jpg',
          },
          {'communityId': 'A', 'status': 'active', 'imageAsset': 'invalid'},
        ], 'A'),
        ['https://example.invalid/new.jpg', 'https://example.invalid/old.jpg'],
      );
    },
  );
  Widget banner(
    List<String> images, {
    bool active = true,
    String scope = 'A',
  }) => MaterialApp(
    home: SizedBox(
      width: 390,
      height: 204,
      child: CommunityImageSlideshow(
        key: ValueKey(scope),
        images: images,
        active: active,
        fallback: image,
        imageProvider: (_) => image,
        foregroundBuilder: (_, index, count) =>
            Text('approved banner $index/$count'),
      ),
    ),
  );
  testWidgets('fallback, five-second rotation and foreground remain intact', (
    tester,
  ) async {
    await tester.pumpWidget(banner([]));
    await tester.pumpAndSettle();
    expect(find.text('approved banner 0/0'), findsOneWidget);
    await tester.pumpWidget(banner(['one', 'two']));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('one')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byKey(const ValueKey('two')), findsOneWidget);
    expect(find.text('approved banner 1/2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'hidden banners pause; changed community discards previous frames',
    (tester) async {
      final images = ['one', 'two'];
      await tester.pumpWidget(banner(images, active: false));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(const ValueKey('one')), findsOneWidget);
      await tester.pumpWidget(banner([], scope: 'B'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('one')), findsNothing);
      expect(find.text('approved banner 0/0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
