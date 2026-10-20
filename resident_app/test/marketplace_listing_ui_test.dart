import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/marketplace_listing_card.dart';
import 'package:resident_app/src/components/marketplace_tabs.dart';
import 'package:resident_app/src/models/listing_model.dart';

ListingModel listing({String status = 'active', int requests = 0}) =>
    ListingModel(
      id: 'listing',
      title: 'Table',
      price: 5600,
      category: 'Furniture',
      condition: 'Like New',
      description: 'Table',
      sellerId: 'resident',
      sellerName: 'Seller',
      buildingId: 'building',
      status: status,
      phoneRequestCount: requests,
      createdAt: DateTime(2026, 10, 20),
    );

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Ahem gives every character a square advance; use Flutter's bundled
    // Android font so row-fit assertions exercise actual mobile typography.
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Flutter SDK bundled Roboto font not found');
      }
      directory = parent;
    }
    final loader = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final bytes = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/$font',
      ).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'equal actions and no overflow at width $width scale $scale',
        (tester) async {
          await mount(
            tester,
            MarketplaceListingCard(
              listing: listing(requests: scale == 2 ? 12 : 0),
              onOpen: () {},
              onEdit: () {},
              onMarkSold: () {},
              onDelete: () {},
            ),
            width: width,
            scale: scale,
            direction: scale == 2 ? TextDirection.rtl : TextDirection.ltr,
          );
          final buttons = [
            find.widgetWithText(OutlinedButton, 'Edit'),
            find.widgetWithText(ElevatedButton, 'Mark Sold'),
            find.widgetWithText(OutlinedButton, 'Delete'),
          ];
          final size = tester.getSize(buttons.first);
          expect(size.height, greaterThanOrEqualTo(48));
          for (final button in buttons) {
            expect(tester.getSize(button), size);
            final widget = tester.widget<ButtonStyleButton>(button);
            expect(
              widget.style!.padding!.resolve({}),
              const EdgeInsets.all(12),
            );
            expect(
              widget.style!.shape!.resolve({}),
              tester
                  .widget<ButtonStyleButton>(buttons.first)
                  .style!
                  .shape!
                  .resolve({}),
            );
          }
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text('Mark Sold'),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          if (scale == 1 && width >= 390) {
            expect(
              tester.getTopLeft(buttons[0]).dy,
              tester.getTopLeft(buttons[1]).dy,
            );
            expect(
              tester.getTopLeft(buttons[1]).dy,
              tester.getTopLeft(buttons[2]).dy,
            );
          }
          if (scale == 2) {
            expect(
              tester.getTopLeft(buttons[1]).dy,
              greaterThan(tester.getTopLeft(buttons[0]).dy),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('card and actions retain separate callbacks', (tester) async {
    final calls = <String>[];
    await mount(
      tester,
      MarketplaceListingCard(
        listing: listing(requests: 1),
        onOpen: () => calls.add('open'),
        onEdit: () => calls.add('edit'),
        onMarkSold: () => calls.add('sold'),
        onDelete: () => calls.add('delete'),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.tap(find.text('Mark Sold'));
    await tester.tap(find.text('Delete'));
    expect(calls, ['edit', 'sold', 'delete']);
    await tester.tap(find.text('1 phone request'));
    await tester.tap(find.text('Table'));
    expect(calls, ['edit', 'sold', 'delete', 'open', 'open']);
  });

  testWidgets('sold label retains status callback', (tester) async {
    var calls = 0;
    await mount(
      tester,
      MarketplaceListingCard(
        listing: listing(status: 'sold'),
        onOpen: () {},
        onEdit: () {},
        onMarkSold: () => calls++,
        onDelete: () {},
      ),
    );
    expect(find.text('Mark Sold'), findsNothing);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sold'));
    expect(calls, 1);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('full tab labels and selection at 320px scale $scale', (
      tester,
    ) async {
      var selected = 0;
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => MarketplaceTabs(
            selectedIndex: selected,
            onChanged: (index) => setState(() => selected = index),
          ),
        ),
        width: 320,
        scale: scale,
      );
      for (final label in ['Browse', 'Your Products', 'History']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          tester.widget<Text>(find.text(label)).overflow,
          TextOverflow.visible,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(selected, ['Browse', 'Your Products', 'History'].indexOf(label));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
