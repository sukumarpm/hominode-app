// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/billing_service.dart';
import 'package:admin_app/services/dashboard_service.dart';
import 'package:admin_app/services/visitor_service.dart';
import 'package:admin_app/visitor_management_screen.dart';
import 'package:admin_app/widgets/standard_bottom_nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> records() =>
    [
          {'status': 'expected', 'isApproved': false},
          {'status': 'pending', 'isApproved': false},
          {'status': 'approved', 'isApproved': true},
          {
            'status': 'inside',
            'isApproved': false,
            'actualArrival': Timestamp.now(),
          },
          {
            'status': 'inside',
            'isApproved': true,
            'actualArrival': Timestamp.now(),
          },
          {'status': 'rejected', 'isApproved': false},
          {
            'status': 'expected',
            'isApproved': false,
            'gateAccessStatus': 'denied',
            'gateEntryDenialReason': 'Gate closed',
          },
          {
            'status': 'completed',
            'actualArrival': Timestamp.now(),
            'departure': Timestamp.now(),
          },
          {'status': 'cancelled'},
          {'status': 'unexpected-legacy-state'},
        ].indexed
        .map<Map<String, dynamic>>(
          (entry) => {
            'communityId': 'C1',
            'visitorName': 'Guest ${entry.$1}',
            'flatId': 'N014',
            'flatLabel': 'N014',
            'purpose': 'Visit',
            'phoneNumber': '1234567890',
            ...entry.$2,
          },
        )
        .toList();

class _Admin extends Fake implements AdminService {
  _Admin([this.community = 'C1', this.uid = 'admin-a']);
  final String community;
  final String? uid;
  @override
  String? getCurrentAdminId() => uid;
  @override
  String requireCurrentCommunityId() => community;
}

class _Billing extends Fake implements BillingService {}

class _English extends AssetLoader {
  const _English();
  static late Map<String, dynamic> strings;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      strings;
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.row);
  @override
  final String id;
  final Map<String, dynamic> row;
  @override
  Map<String, dynamic> data() => row;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(List<Map<String, dynamic>> rows)
    : docs = rows.indexed.map((e) => _Doc('v${e.$1}', e.$2)).toList();
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Db extends Fake implements FirebaseFirestore {
  final rows = <String, List<Map<String, dynamic>>>{
    'visitors': records(),
    'users': [
      {'role': 'resident', 'communityId': 'C1'},
    ],
    'flats': [],
    'bills': [],
    'complaints': [],
  };
  final changes = <String, StreamController<void>>{};
  final queries = <({String collection, Object field, Object? value})>[];
  final getCalls = <String, int>{};
  Duration getDelay = Duration.zero;
  int activeGetCalls = 0;
  int maxConcurrentGetCalls = 0;
  DateTime? firstGetStartedAt;
  DateTime? lastGetCompletedAt;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this, path);
  void emit(String path) => changes[path]?.add(null);
  Future<void> close() async {
    for (final controller in changes.values) {
      await controller.close();
    }
  }
}

class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(this.db, this.name);
  final _Db db;
  final String name;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      db.queries.add((
        collection: name,
        field: invocation.positionalArguments.single,
        value: invocation.namedArguments[#isEqualTo],
      ));
      return this;
    }
    return super.noSuchMethod(invocation);
  }

  // Deliberately include foreign rows to test the client's defense-in-depth filter.
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    db.getCalls.update(
      name,
      (currentCount) => currentCount + 1,
      ifAbsent: () => 1,
    );
    db.firstGetStartedAt ??= DateTime.now();
    db.activeGetCalls++;
    if (db.activeGetCalls > db.maxConcurrentGetCalls) {
      db.maxConcurrentGetCalls = db.activeGetCalls;
    }
    if (db.getDelay > Duration.zero) await Future<void>.delayed(db.getDelay);
    db.activeGetCalls--;
    db.lastGetCompletedAt = DateTime.now();
    return _Snapshot(db.rows[name] ?? []);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield _Snapshot(db.rows[name] ?? []);
    yield* (db.changes.putIfAbsent(
      name,
      () => StreamController<void>.broadcast(),
    )).stream.map((_) => _Snapshot(db.rows[name] ?? []));
  }
}

class _Workflow extends Fake implements VisitorWorkflowService {
  final rows = records().indexed
      .map((e) => VisitorModel.fromFirestore('v${e.$1}', e.$2))
      .toList();
  @override
  Stream<List<VisitorModel>> getPendingVisitors() => Stream.value(
    rows.where((r) => visitorBelongsInExpectedQueue(r.lifecycleData)).toList(),
  );
  @override
  Stream<List<VisitorModel>> getActiveVisitors() => Stream.value(
    rows.where((r) => visitorBelongsInActiveQueue(r.lifecycleData)).toList(),
  );
  @override
  Stream<List<VisitorModel>> getHistoryVisitors() => Stream.value(
    rows.where((r) => visitorBelongsInHistoryQueue(r.lifecycleData)).toList(),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _English.strings =
        jsonDecode(await rootBundle.loadString('assets/translations/en.json'))
            as Map<String, dynamic>;
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      if (directory.parent.path == directory.path) {
        throw StateError('Flutter font not found');
      }
      directory = directory.parent;
    }
    final fonts = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      fonts.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${directory.path}/bin/cache/artifacts/material_fonts/$font',
            ).readAsBytesSync(),
          ),
        ),
      );
    }
    await fonts.load();
  });

  test('old approvals can be renewed through Admin while terminal visits cannot', () {
    for (final authorization in [null, 'pending_admin', 'auto_authorized', 'admin_authorized']) {
      expect(visitorCanDecide({'status': 'approved', 'isApproved': true,
        'authorizationState': authorization}), isTrue);
    }
    for (final status in ['inside', 'completed', 'rejected', 'cancelled']) {
      expect(visitorCanDecide({'status': status, 'authorizationState': 'admin_authorized'}), isFalse);
    }
  });

  test(
    'every relevant state belongs to exactly one physical queue, independently of approval',
    () {
      final rows = records();
      for (final row in rows) {
        expect(
          [
            visitorBelongsInExpectedQueue(row),
            visitorBelongsInActiveQueue(row),
            visitorBelongsInHistoryQueue(row),
          ].where((v) => v).length,
          1,
        );
      }
      expect(rows.where(visitorBelongsInExpectedQueue).length, 3);
      expect(rows.where(visitorBelongsInActiveQueue).length, 2);
      expect(rows.where(visitorBelongsInHistoryQueue).length, 5);
      expect(visitorBelongsInActiveQueue(rows[3]), isTrue);
      expect(visitorBelongsInHistoryQueue(rows[5]), isTrue);
      expect(visitorBelongsInHistoryQueue(rows[6]), isTrue);
    },
  );

  test(
    'dashboard pending count includes expected/pending only, excludes foreign/approved/inside/terminal',
    () {
      expect(
        pendingVisitorCount([
          ...records(),
          {...records().first, 'communityId': 'C2'},
        ], 'C1'),
        2,
      );
    },
  );

  test(
    'all service queues use the active community and do not cap History at 50',
    () async {
      final db = _Db();
      addTearDown(db.close);
      db.rows['visitors']!.add({
        'communityId': 'C2',
        'status': 'expected',
        'visitorName': 'Foreign',
      });
      for (var i = 0; i < 55; i++) {
        db.rows['visitors']!.add({
          'communityId': 'C1',
          'status': 'rejected',
          'visitorName': 'Old $i',
        });
      }
      final service = VisitorService(firestore: db, adminService: _Admin());
      final expected = await service.getPendingVisitors().first;
      final inside = await service.getActiveVisitors().first;
      final history = await service.getHistoryVisitors().first;
      expect(expected.length, 3);
      expect(inside.length, 2);
      expect(history.length, 60);
      expect(
        [
          ...expected,
          ...inside,
          ...history,
        ].any((r) => r.visitorName == 'Foreign'),
        isFalse,
      );
      expect(
        db.queries
            .where((q) => q.field == 'communityId')
            .every((q) => q.value == 'C1'),
        isTrue,
      );
      final other = VisitorService(firestore: db, adminService: _Admin('C2'));
      expect((await other.getVisitors().first).single.visitorName, 'Foreign');
    },
  );

  test('an unauthenticated Admin service does not query visitors', () async {
    final db = _Db();
    addTearDown(db.close);
    final service = VisitorService(
      firestore: db,
      adminService: _Admin('C1', null),
    );
    expect(await service.getVisitors().first, isEmpty);
    expect(db.queries, isEmpty);
  });

  test(
    'dashboard stream refreshes visitor decisions without a resident-roster change',
    () async {
      final db = _Db();
      addTearDown(db.close);
      final dashboard = DashboardService(
        firestore: db,
        billingService: _Billing(),
      );
      final events = <DashboardStats>[];
      final subscription = dashboard.getDashboardStats('C1').listen(events.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      expect(events.last.pendingVisitors, 2);
      db.rows['visitors']![0] = {
        ...db.rows['visitors']![0],
        'status': 'approved',
        'isApproved': true,
      };
      db.emit('visitors');
      await Future<void>.delayed(Duration.zero);
      expect(events.last.pendingVisitors, 1);
      expect(await dashboard.getPendingVisitorsCount('C1').first, 1);
    },
  );

  test('dashboard preserves totals and avoids rereading visitor snapshots', () async {
    final db = _Db()..getDelay = const Duration(milliseconds: 10);
    db.rows['flats'] = [
      {'communityId': 'C1'},
      {'communityId': 'C1'},
    ];
    db.rows['complaints'] = [
      {'communityId': 'C1', 'status': 'pending'},
      {'communityId': 'C1', 'status': 'in-progress'},
      {'communityId': 'C1', 'status': 'resolved'},
    ];
    final now = DateTime.now();
    db.rows['bills'] = [
      {
        'communityId': 'C1',
        'status': 'paid',
        'paidAt': Timestamp.fromDate(now),
        'amount': 100,
      },
      {
        'communityId': 'C1',
        'status': 'paid',
        'paidAt': Timestamp.fromDate(now),
        'amount': 250,
      },
      {
        'communityId': 'C1',
        'status': 'pending',
        'paidAt': Timestamp.fromDate(now),
        'amount': 900,
      },
    ];
    addTearDown(db.close);
    final dashboard = DashboardService(
      firestore: db,
      billingService: _Billing(),
    );
    final events = <DashboardStats>[];
    final subscription = dashboard.getDashboardStats('C1').listen(events.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(events, isNotEmpty);
    expect(events.first.totalResidents, 1);
    expect(events.first.totalFlats, 2);
    expect(events.first.pendingVisitors, 2);
    expect(events.first.pendingComplaints, 2);
    expect(events.first.monthlyCollection, 350);
    expect(db.getCalls, {'flats': 1, 'complaints': 1, 'bills': 1});
    expect(db.maxConcurrentGetCalls, 3);
    for (final collection in [
      'users',
      'visitors',
      'flats',
      'complaints',
      'bills',
    ]) {
      expect(
        db.queries.any(
          (query) =>
              query.collection == collection &&
              query.field == 'communityId' &&
              query.value == 'C1',
        ),
        isTrue,
        reason: '$collection dashboard reads stay community-scoped',
      );
    }
    // Controlled 10 ms per mocked Firestore get; this is a local harness
    // measurement, not a production latency measurement.
    // ignore: avoid_print
    print(
      'Dashboard initial: reads=${db.getCalls.values.fold<int>(0, (a, b) => a + b)} '
      'syntheticGetSpanMs=${db.lastGetCompletedAt!.difference(db.firstGetStartedAt!).inMilliseconds} '
      'maxConcurrentGets=${db.maxConcurrentGetCalls}',
    );

    db.getCalls.clear();
    db.firstGetStartedAt = null;
    db.lastGetCompletedAt = null;
    db.maxConcurrentGetCalls = 0;
    db.rows['visitors']![0] = {
      ...db.rows['visitors']![0],
      'status': 'approved',
      'isApproved': true,
    };
    db.emit('visitors');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(events.last.pendingVisitors, 1);
    expect(events.last.totalFlats, 2);
    expect(events.last.pendingComplaints, 2);
    expect(events.last.monthlyCollection, 350);
    expect(db.getCalls, {'flats': 1, 'complaints': 1, 'bills': 1});
    expect(db.maxConcurrentGetCalls, 3);
    // ignore: avoid_print
    print(
      'Dashboard visitor refresh: reads=${db.getCalls.values.fold<int>(0, (a, b) => a + b)} '
      'syntheticGetSpanMs=${db.lastGetCompletedAt!.difference(db.firstGetStartedAt!).inMilliseconds} '
      'maxConcurrentGets=${db.maxConcurrentGetCalls}',
    );
    await subscription.cancel();
  });

  test('dashboard stats stream is reused until the community changes', () {
    final createdFor = <String>[];
    final cache = DashboardStatsStreamCache((communityId) {
      createdFor.add(communityId);
      return Stream<DashboardStats>.empty();
    });

    final first = cache.forCommunity('C1');
    expect(identical(cache.forCommunity('C1'), first), isTrue);
    final switched = cache.forCommunity('C2');
    expect(identical(switched, first), isFalse);
    expect(identical(cache.forCommunity('C2'), switched), isTrue);
    expect(createdFor, ['C1', 'C2']);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double width = 393,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 960);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        path: 'assets/translations',
        assetLoader: const _English(),
        saveLocale: false,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          child: home,
          builder: (context, child) => MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: child,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'iOS Visitors navigation opens the existing screen and approved arrivals offer no duplicate decision',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          body: const Text('Home screen'),
          bottomNavigationBar: StandardBottomNav(
            selectedIndex: 0,
            visitorsBuilder: (_) =>
                VisitorManagementScreen(visitorService: _Workflow()),
          ),
        ),
      );
      await tester.tap(find.text('Visitors'));
      await tester.pumpAndSettle();
      expect(find.byType(VisitorManagementScreen), findsOneWidget);
      expect(find.text('Guest 0'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Guest 2'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(PageView),
              matching: find.byType(Scrollable),
            )
            .at(1),
      );
      expect(find.text('Guest 2'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('visitor-v2')),
          matching: find.text('Approve'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Inside and History show visits without Admin approval and terminal outcomes without invented dates',
    (tester) async {
      await mount(
        tester,
        VisitorManagementScreen(visitorService: _Workflow()),
        width: 800,
      );
      await tester.tap(find.text('Inside').first);
      await tester.pumpAndSettle();
      expect(find.text('Guest 3'), findsOneWidget);
      expect(find.text('Admin approval: Not recorded'), findsOneWidget);
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        2,
      );
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Entry denied'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    },
  );

  testWidgets(
    'managed pending invitations have a separate review queue and no physical check-in',
    (tester) async {
      final service = _Workflow();
      service.rows.add(
        VisitorModel.fromFirestore('managed', {
          'visitorName': 'Managed Guest',
          'hostName': 'Host',
          'communityId': 'C1',
          'flatLabel': 'N014',
          'status': 'expected',
          'isApproved': false,
          'authorizationManaged': true,
          'authorizationState': 'pending_admin',
          'authorizationRevision': 7,
        }),
      );
      await mount(
        tester,
        VisitorManagementScreen(visitorService: service),
        width: 800,
      );
      expect(find.text('Managed Guest'), findsNothing);
      await tester.tap(find.text('Pending approval').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        3,
      );
      expect(find.text('Managed Guest'), findsOneWidget);
      expect(
        find.text('Authorization: Pending Admin approval'),
        findsOneWidget,
      );
      expect(
        find.text('Physical visit: Expected — not checked in'),
        findsOneWidget,
      );
      expect(find.text('Guest 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [393.0, 600.0, 800.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('iOS navigation and visitor queues fit $width at $scale', (
        tester,
      ) async {
        await mount(
          tester,
          VisitorManagementScreen(visitorService: _Workflow()),
          width: width,
          scale: scale,
        );
        expect(find.text('Visitors'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
