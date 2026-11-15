// Firestore query doubles let tests control network completion without production hooks.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/widgets/create_monthly_bill_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/admin_test_localization.dart';

class _Store extends Fake implements FirebaseFirestore {
  final data = FakeFirebaseFirestore();
  Completer<void>? gate;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      path == 'flats'
      ? _Collection(data.collection(path), () => gate?.future ?? Future.value())
      : data.collection(path);
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.query, this.wait);
  final Query<Map<String, dynamic>> query;
  final Future<void> Function() wait;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #where) {
      return _Query(
        query.where(
          call.positionalArguments.first,
          isEqualTo: call.namedArguments[#isEqualTo],
        ),
        wait,
      );
    }
    return super.noSuchMethod(call);
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    await wait();
    return query.get(options);
  }
}

class _Collection extends _Query
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(super.query, super.wait);
}

void main() {
  setUpAll(initializeAdminTestLocalization);
  Future<void> openPicker(WidgetTester tester, _Store db) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AdminTenantContext.instance.initialize(
      const AdminProfile(
        uid: 'admin',
        phoneNumber: '+639171234567',
        role: 'admin',
        isActive: true,
        authorizedCommunityIds: ['A'],
      ),
    );
    await db.data.collection('buildings').doc('pulse').set({
      'communityId': 'A',
      'name': 'Pulse',
    });
    await tester.pumpWidget(
      localizedAdminTestApp(
        Scaffold(
          body: CreateMonthlyBillModal(firestore: db, onGenerate: (_) {}),
        ),
        designSize: const Size(1000, 1600),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String label) async {
      final finder = find.text(label).last;
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tap('All Residents');
    await tap('Specific Units');
    await tap('Choose building...');
    await tap('Pulse');
    await tap('Select units');
  }

  testWidgets('open unit picker updates from loading to scoped results', (
    tester,
  ) async {
    final db = _Store()..gate = Completer<void>();
    for (final row in [
      ('one', 'A', 'pulse'),
      ('foreign', 'B', 'pulse'),
      ('other', 'A', 'other'),
    ]) {
      await db.data.collection('flats').doc(row.$1).set({
        'communityId': row.$2,
        'buildingId': row.$3,
        'flatLabel': row.$1,
        'status': 'vacant',
      });
    }
    await openPicker(tester, db);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    db.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    expect(find.text('foreign'), findsNothing);
    expect(find.text('other'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets(
    'unit query failure displays Retry and retry resolves to empty state',
    (tester) async {
      final db = _Store()..gate = Completer<void>();
      await openPicker(tester, db);
      db.gate!.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to load units'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      db.gate = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No flats found for this building'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );
}
