import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';
import 'package:resident_app/src/models/listing_model.dart';
import 'package:resident_app/src/screens/marketplace_screen.dart';
import 'package:resident_app/src/screens/marketplace_create_listing_screen.dart';
import 'package:resident_app/src/screens/marketplace_edit_listing_screen.dart';
import 'package:resident_app/src/screens/marketplace_your_products_screen.dart';
import 'package:resident_app/src/screens/marketplace_product_detail_screen.dart';
import 'package:resident_app/src/screens/marketplace_your_product_detail_screen.dart';
import 'package:resident_app/src/screens/marketplace_buyer_phone_view_screen.dart';
import 'package:resident_app/src/widgets/marketplace_access_gate.dart';

HominodeEntitlement entitlement(String plan, {int? endsAtMs}) =>
    HominodeEntitlement(
      communityId: 'A',
      planId: plan,
      status: HominodeSubscriptionStatus.active,
      endsAtMs: endsAtMs,
      features: {'marketplace': plan != 'essential', 'communityWall': true},
      limits: const {},
    );

Widget host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: child),
);

void main() {
  for (final plan in ['essential', 'plus', 'pro']) {
    testWidgets('$plan gates content before it mounts', (tester) async {
      final pending = Completer<HominodeEntitlement?>();
      var builds = 0;
      await tester.pumpWidget(
        host(
          MarketplaceAccessGate(
            loader: () => pending.future,
            builder: (_) {
              builds++;
              return const Text('Authorized content');
            },
          ),
        ),
      );
      expect(builds, 0);
      pending.complete(entitlement(plan));
      await tester.pumpAndSettle();
      expect(builds > 0, plan != 'essential');
      expect(
        find.text('Marketplace requires Plus or Pro.'),
        plan == 'essential' ? findsOneWidget : findsNothing,
      );
      expect(entitlement(plan).canUseFeature('communityWall'), isTrue);
    });
  }

  testWidgets('late cached Pro result cannot replace newer Essential denial', (
    tester,
  ) async {
    final old = Completer<HominodeEntitlement?>();
    final changes = StreamController<void>();
    addTearDown(changes.close);
    var calls = 0;
    await tester.pumpWidget(
      host(
        MarketplaceAccessGate(
          loader: () => ++calls == 1
              ? old.future
              : Future.value(entitlement('essential')),
          invalidations: changes.stream,
          builder: (_) => const Text('Authorized content'),
        ),
      ),
    );
    changes.add(null);
    await tester.pumpAndSettle();
    old.complete(entitlement('pro'));
    await tester.pumpAndSettle();
    expect(find.text('Authorized content'), findsNothing);
    expect(find.text('Marketplace requires Plus or Pro.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live downgrade removes previously authorized content', (
    tester,
  ) async {
    var current = entitlement('pro');
    final changes = StreamController<void>();
    addTearDown(changes.close);
    await tester.pumpWidget(
      host(
        MarketplaceAccessGate(
          loader: () async => current,
          invalidations: changes.stream,
          builder: (_) => const Text('Authorized content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorized content'), findsOneWidget);
    current = entitlement('essential');
    changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Authorized content'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('verification failure retries without mounting content', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        MarketplaceAccessGate(
          loader: () async {
            if (++calls == 1) throw StateError('offline');
            return entitlement('plus');
          },
          builder: (_) => const Text('Authorized content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Marketplace access could not be verified.'),
      findsOneWidget,
    );
    expect(find.text('Authorized content'), findsNothing);
    await tester.tap(find.text('Check access again'));
    await tester.pumpAndSettle();
    expect(find.text('Authorized content'), findsOneWidget);
  });

  testWidgets('expired Pro cannot mount content', (tester) async {
    await tester.pumpWidget(
      host(
        MarketplaceAccessGate(
          loader: () async => entitlement('pro', endsAtMs: 1),
          builder: (_) => const Text('Authorized content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorized content'), findsNothing);
  });

  testWidgets('disposal ignores pending authorization', (tester) async {
    final pending = Completer<HominodeEntitlement?>();
    await tester.pumpWidget(
      host(
        MarketplaceAccessGate(
          loader: () => pending.future,
          builder: (_) => const Text('Authorized content'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete(entitlement('pro'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  final listing = ListingModel(
    id: 'listing',
    communityId: 'A',
    title: 'Chair',
    price: 10,
    category: 'Furniture',
    condition: 'Good',
    description: '',
    sellerId: 'owner',
    sellerName: 'Owner',
    buildingId: 'building',
  );
  Future<HominodeEntitlement?> essential() async => entitlement('essential');
  final routes = <String, Widget>{
    'browse': MarketplaceScreen(accessLoader: essential),
    'create': MarketplaceCreateListingScreen(accessLoader: essential),
    'edit': MarketplaceEditListingScreen(
      listing: listing,
      accessLoader: essential,
    ),
    'your products': MarketplaceYourProductsScreen(accessLoader: essential),
    'product detail': MarketplaceProductDetailScreen(
      listing: listing,
      accessLoader: essential,
    ),
    'seller detail': MarketplaceYourProductDetailScreen(
      listing: listing,
      accessLoader: essential,
    ),
    'buyer contact': MarketplaceBuyerPhoneViewScreen(
      listing: listing,
      accessLoader: essential,
    ),
  };
  for (final entry in routes.entries) {
    testWidgets(
      'direct ${entry.key} navigation denies Essential before Firebase reads',
      (tester) async {
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => entry.value),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Marketplace requires Plus or Pro.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.arrow_back_ios));
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
      },
    );
  }
}
