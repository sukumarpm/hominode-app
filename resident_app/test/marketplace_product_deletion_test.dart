import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/listing_model.dart';
import 'package:resident_app/src/screens/marketplace_your_product_detail_screen.dart';
import 'package:resident_app/src/screens/marketplace_your_products_screen.dart';
import 'package:resident_app/src/services/listing_firestore_service.dart';
import 'package:resident_app/src/widgets/marketplace_delete_listing_dialog.dart';

import 'marketplace_access_gate_test.dart' show entitlement;
import 'marketplace_listing_ui_test.dart' show listing;

class _Listings extends Fake implements ListingFirestoreService {
  final deletedIds = <String>[];
  final products = [listing()];
  Future<ServiceResult> Function() delete = () async =>
      ServiceResult(success: true);

  @override
  Future<List<ListingModel>> getMyListings() async => List.of(products);

  @override
  Stream<List<Map<String, dynamic>>> streamPhoneRequestsForListing(String id) =>
      Stream.value([]);

  @override
  Future<ServiceResult> deleteListing(String id) {
    deletedIds.add(id);
    return delete();
  }
}

void main() {
  late _Listings service;
  setUp(() => service = _Listings());

  Future<void> open(WidgetTester tester, {bool detail = false}) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: detail
                          ? MarketplaceYourProductDetailScreen(
                              listing: service.products.first,
                              listingService: service,
                              accessLoader: () async => entitlement('plus'),
                            )
                          : MarketplaceYourProductsScreen(
                              listingService: service,
                              accessLoader: () async => entitlement('plus'),
                            ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final action = find.widgetWithText(
      OutlinedButton,
      detail ? 'Delete Product' : 'Delete',
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(service.deletedIds, isEmpty);
  }

  Future<void> confirm(WidgetTester tester) async {
    final button = find.widgetWithText(TextButton, 'Delete');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Deleting…'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Deleting…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    expect(service.deletedIds, ['listing']);
    // System back must not dismiss confirmation while the operation is pending.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Deleting…'), findsOneWidget);
  }

  for (final detail in [false, true]) {
    final label = detail ? 'seller detail' : 'Your Products';
    testWidgets('$label confirmation cancellation never deletes', (
      tester,
    ) async {
      await open(tester, detail: detail);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(service.deletedIds, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('$label loading awaits actual deletion and succeeds once', (
      tester,
    ) async {
      final pending = Completer<ServiceResult>();
      service.delete = () => pending.future;
      await open(tester, detail: detail);
      await confirm(tester);
      pending.complete(ServiceResult(success: true));
      await tester.pumpAndSettle();
      expect(service.deletedIds, ['listing']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Listing deleted successfully'), findsOneWidget);
      if (detail) {
        expect(find.byType(MarketplaceYourProductDetailScreen), findsNothing);
      } else {
        expect(find.text('Table'), findsNothing);
        expect(find.text('No products yet'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$label failure keeps listing and permits retry', (
      tester,
    ) async {
      final pending = Completer<ServiceResult>();
      service.delete = () => pending.future;
      await open(tester, detail: detail);
      await confirm(tester);
      pending.complete(
        ServiceResult(
          success: false,
          message: 'Unable to remove the listing. Please reload and retry.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deleting…'), findsNothing);
      expect(find.textContaining('Please reload and retry'), findsOneWidget);
      expect(find.text('Listing deleted successfully'), findsNothing);
      expect(find.text('Table'), detail ? findsNWidgets(2) : findsOneWidget);
      service.delete = () async => ServiceResult(success: true);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(service.deletedIds, ['listing', 'listing']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Listing deleted successfully'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final fail in [false, true]) {
      testWidgets(
        '$label disposed during ${fail ? 'failed' : 'successful'} deletion',
        (tester) async {
          final pending = Completer<ServiceResult>();
          service.delete = () => pending.future;
          await open(tester, detail: detail);
          await confirm(tester);
          await tester.pumpWidget(const SizedBox());
          if (fail) {
            pending.completeError(StateError('Synthetic failure'));
          } else {
            pending.complete(ServiceResult(success: true));
          }
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'removed dialog ignores completion and does not pop the products screen',
    (tester) async {
      final pending = Completer<ServiceResult>();
      service.delete = () => pending.future;
      await open(tester);
      await confirm(tester);
      final context = tester.element(
        find.byType(MarketplaceDeleteListingDialog),
      );
      Navigator.of(context).removeRoute(ModalRoute.of(context)!);
      await tester.pumpAndSettle();
      pending.complete(ServiceResult(success: true));
      await tester.pumpAndSettle();
      expect(find.byType(MarketplaceYourProductsScreen), findsOneWidget);
      expect(find.text('Listing deleted successfully'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unexpected deletion exception restores retry controls', (
    tester,
  ) async {
    service.delete = () async => throw StateError('Synthetic failure');
    await open(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Check your connection and retry'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
          .onPressed,
      isNotNull,
    );
    expect(find.text('Table'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
