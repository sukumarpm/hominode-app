import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/security_user_model.dart';
import 'package:security_app/services/auth_service.dart';
import 'package:security_app/services/security_inbox_service.dart';

const officer = SecurityUserModel(
  uid: 'guard-a',
  communityId: 'C1',
  role: 'security',
  isActive: true,
  name: 'Officer A',
  phoneNumber: '+639171234567',
);

SecurityInboxNotification notice({
  String id = 'n1',
  Map<String, dynamic> overrides = const {},
}) => SecurityInboxNotification(id, {
  ...securityInboxFilters(officer),
  'title': 'Community update',
  'message': 'Please review your assignment.',
  'createdAt': Timestamp.fromDate(DateTime(2026, 11, 9, 8)),
  'isRead': false,
  ...overrides,
});

class InboxTestUser extends Fake implements User {
  InboxTestUser(this.uid);
  @override
  final String uid;
}

class InboxTestAuth extends Fake implements AuthService {
  SecurityUserModel profile = officer;
  User? user = InboxTestUser(officer.uid);
  final changes = StreamController<User?>.broadcast();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> get authStateChanges async* {
    yield user;
    yield* changes.stream;
  }

  @override
  Future<SecurityUserModel> requireSecurityProfile({
    bool Function()? isSessionCurrent,
  }) async => profile;
}

class _Store implements SecurityInboxStore {
  final rows = StreamController<List<SecurityInboxNotification>>.broadcast();
  final queries = <Map<String, String>>[];
  final writes = <String>[];
  SecurityInboxNotification record = notice();
  Object? writeError;
  @override
  Stream<List<SecurityInboxNotification>> watch(Map<String, String> filters) {
    queries.add(filters);
    return rows.stream;
  }

  @override
  Future<SecurityInboxNotification> get(String id) async => record;
  @override
  Future<void> markRead(String id) async {
    if (writeError != null) throw writeError!;
    writes.add(id);
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late InboxTestAuth auth;
  late _Store store;
  late SecurityInboxService service;
  setUp(() {
    auth = InboxTestAuth();
    store = _Store();
    service = SecurityInboxService(auth: auth, store: store);
  });
  tearDown(() async {
    await auth.changes.close();
    await store.rows.close();
  });

  test(
    'queries and filters by verified recipient, community and all Security routing fields',
    () async {
      final events = <List<SecurityInboxNotification>>[];
      final subscription = service.watch().listen(events.add);
      await flush();
      expect(store.queries.single, {
        'communityId': 'C1',
        'recipientId': 'guard-a',
        'audience': 'security',
        'role': 'security',
        'appId': 'security',
      });
      store.rows.add([
        notice(),
        notice(id: 'other-user', overrides: {'recipientId': 'guard-b'}),
        notice(id: 'other-community', overrides: {'communityId': 'C2'}),
        for (final field in ['audience', 'role', 'appId'])
          notice(id: field, overrides: {field: 'admin'}),
        notice(id: 'deleted', overrides: {'deletedAt': Timestamp.now()}),
        notice(
          id: 'sos',
          overrides: {'type': 'sos', 'sourceEntityId': 'SOS-1'},
        ),
      ]);
      await flush();
      expect(events.single.map((r) => r.id), ['n1', 'sos']);
      await subscription.cancel();
    },
  );

  test(
    'sign-out invalidates displayed results and stops the previous query',
    () async {
      final events = <List<SecurityInboxNotification>>[], errors = <Object>[];
      final subscription = service.watch().listen(
        events.add,
        onError: errors.add,
      );
      await flush();
      store.rows.add([notice()]);
      await flush();
      auth.user = null;
      auth.changes.add(null);
      await flush();
      expect(errors, isNotEmpty);
      store.rows.add([notice(id: 'stale')]);
      await flush();
      expect(events.last.single.id, 'n1');
      expect(store.rows.hasListener, isFalse);
      await subscription.cancel();
    },
  );

  test(
    'auth errors stop old notification results from being republished',
    () async {
      final events = <List<SecurityInboxNotification>>[];
      final errors = <Object>[];
      final subscription = service.watch().listen(
        events.add,
        onError: errors.add,
      );
      await flush();
      store.rows.add([notice()]);
      await flush();
      auth.changes.addError(StateError('Authentication unavailable'));
      await flush();
      store.rows.add([notice(id: 'stale')]);
      await flush();
      expect(errors, isNotEmpty);
      expect(store.rows.hasListener, isFalse);
      expect(events.last.single.id, 'n1');
      await subscription.cancel();
    },
  );

  test(
    'a new identity receives its own query without retaining the old subscription',
    () async {
      final errors = <Object>[];
      final subscription = service.watch().listen((_) {}, onError: errors.add);
      await flush();
      auth.profile = const SecurityUserModel(
        uid: 'guard-b',
        communityId: 'C2',
        role: 'security',
        isActive: true,
        name: 'Officer B',
        phoneNumber: '+639171234568',
      );
      auth.user = InboxTestUser('guard-b');
      auth.changes.add(auth.user);
      await flush();
      expect(errors, isNotEmpty);
      expect(store.queries.last['recipientId'], 'guard-b');
      expect(store.queries.last['communityId'], 'C2');
      await subscription.cancel();
    },
  );

  test('read updates revalidate the stored recipient and community', () async {
    await service.markRead(notice());
    expect(store.writes, ['n1']);
    for (final foreign in [
      {'recipientId': 'guard-b'},
      {'communityId': 'C2'},
      {'appId': 'admin'},
    ]) {
      store.record = notice(overrides: foreign);
      await expectLater(service.markRead(notice()), throwsStateError);
    }
    expect(store.writes, ['n1']);
  });

  test(
    'read updates reject a mismatched authenticated identity and propagate failures',
    () async {
      auth.user = InboxTestUser('guard-b');
      await expectLater(service.markRead(notice()), throwsStateError);
      expect(store.writes, isEmpty);
      auth.user = InboxTestUser(officer.uid);
      store.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await expectLater(
        service.markRead(notice()),
        throwsA(isA<FirebaseException>()),
      );
    },
  );

  test('permission, index and connection errors are actionable', () {
    expect(
      securityInboxError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('access denied'),
    );
    expect(
      securityInboxError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
        ),
      ),
      contains('indexes'),
    );
    expect(securityInboxError(Exception('offline')), contains('connection'));
  });
}
