import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/marketplace_image_gallery.dart';

final bytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
);
void main() {
  Future<void> show(
    WidgetTester tester,
    List<String> images, {
    double scale = 1,
    ImageProvider Function(String)? provider,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MarketplaceImageGallery(
              images: images,
              imageProvider: provider ?? (_) => MemoryImage(bytes),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zero images has a quiet fallback and no gallery controls', (
    tester,
  ) async {
    await show(tester, []);
    expect(find.text('No images available'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('Swipe for more images'), findsNothing);
  });
  testWidgets(
    'single image opens full viewer with zoom and close, without indicators',
    (tester) async {
      await show(tester, ['one']);
      expect(find.text('1/1'), findsNothing);
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.maxScale, 4);
      expect(find.text('Product images'), findsOneWidget);
      await tester.tap(find.byTooltip('Close image viewer'));
      await tester.pumpAndSettle();
      expect(find.text('Product images'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved order, counter, dots and full-screen starting image follow swipes',
    (tester) async {
      final reads = <String>[];
      await show(
        tester,
        ['first', 'second', 'third'],
        provider: (reference) {
          reads.add(reference);
          return MemoryImage(bytes);
        },
      );
      expect(reads.first, 'first');
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Swipe for more images'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(reads, contains('second'));
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('2/3').last, findsOneWidget);
      await tester.drag(find.byType(PageView).last, const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(reads, contains('third'));
      await tester.tap(find.byTooltip('Close image viewer'));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
    },
  );
  testWidgets('missing and failed images show fallback', (tester) async {
    await show(tester, ['']);
    expect(find.text('Image unavailable'), findsOneWidget);
    await show(tester, [
      'bad',
    ], provider: (_) => MemoryImage(Uint8List.fromList([0])));
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'narrow layout and enlarged text fit; replacement and disposal are safe',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, ['a', 'b'], scale: 2);
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      await show(tester, ['replacement'], scale: 2);
      expect(find.text('1/1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
