import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/notice_model.dart';
import 'package:resident_app/src/services/notice_firestore_service.dart';

NoticeModel notice(String id) => NoticeModel(
  id: id,
  title: 'Synthetic',
  content: 'Synthetic',
  authorId: 'admin',
  authorName: 'Admin',
  publishDate: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
void main() {
  test(
    'unread stream refreshes read receipts and releases listeners and timer',
    () async {
      final auth = _Auth(_User('resident'));
      addTearDown(auth.close);
      var read = false, loads = 0;
      final service = NoticeFirestoreService.forTesting(
        auth: auth,
        notices: () async {
          loads++;
          return [notice('notice')];
        },
        isRead: (_) async => read,
      );
      final values = <int>[], timers = <_RefreshTimer>[];
      final subscription = _listen(service, values, timers);
      await _flush();
      expect(values.last, 1);
      expect(timers.single.interval, const Duration(seconds: 60));
      read = true;
      service.refreshUnreadCount();
      await _flush();
      expect(values.last, 0);
      timers.single.fire();
      await _flush();
      expect(loads, 3);
      await subscription.cancel();
      expect(auth.changes.hasListener, false);
      expect(timers.single.isActive, false);
      final before = loads;
      service.refreshUnreadCount();
      timers.single.fire();
      await _flush();
      expect(loads, before);
    },
  );
  test(
    'replacement gets a fresh stream and ignores the cancelled scope late result',
    () async {
      final auth = _Auth(_User('resident'));
      addTearDown(auth.close);
      final pending = Completer<List<NoticeModel>>();
      var loads = 0;
      final service = NoticeFirestoreService.forTesting(
        auth: auth,
        notices: () async => ++loads == 1 ? pending.future : [],
        isRead: (_) async => false,
      );
      final oldValues = <int>[],
          nextValues = <int>[],
          timers = <_RefreshTimer>[];
      final previous = _listen(service, oldValues, timers);
      await _flush();
      expect(loads, 1);
      await previous.cancel();
      final next = _listen(service, nextValues, timers);
      await _flush();
      expect(loads, 2);
      pending.complete([notice('old-tenant')]);
      await _flush();
      expect(oldValues, everyElement(0));
      expect(nextValues, everyElement(0));
      await next.cancel();
      expect(auth.changes.hasListener, false);
      expect(timers.every((timer) => !timer.isActive), true);
    },
  );
  test(
    'logout clears unread state and rejects an in-flight previous identity count',
    () async {
      final auth = _Auth(_User('resident'));
      addTearDown(auth.close);
      final pending = Completer<List<NoticeModel>>();
      final service = NoticeFirestoreService.forTesting(
        auth: auth,
        notices: () => pending.future,
        isRead: (_) async => false,
      );
      final values = <int>[], timers = <_RefreshTimer>[];
      final subscription = _listen(service, values, timers);
      await _flush();
      auth.currentUser = null;
      auth.changes.add(null);
      await _flush();
      pending.complete([notice('previous-user')]);
      await _flush();
      expect(values, everyElement(0));
      await subscription.cancel();
      expect(auth.changes.hasListener, false);
      expect(timers.single.isActive, false);
    },
  );

  test(
    'unread count uses only actual inbox notices and persisted read state',
    () async {
      final checked = <String>[];
      final service = NoticeFirestoreService.forTesting(
        notices: () async => [notice('read'), notice('unread')],
        isRead: (id) async {
          checked.add(id);
          return id == 'read';
        },
      );
      expect(await service.getUnreadCount(), 1);
      expect(checked, ['read', 'unread']);
    },
  );
  test(
    'empty inbox has zero unread notifications without extra read requests',
    () async {
      final service = NoticeFirestoreService.forTesting(
        notices: () async => [],
        isRead: (_) async => throw StateError('unexpected'),
      );
      expect(await service.getUnreadCount(), 0);
    },
  );
  test(
    'unavailable read status does not invent unread notifications',
    () async {
      final service = NoticeFirestoreService.forTesting(
        notices: () async => [notice('unknown')],
        isRead: (_) async => throw StateError('unavailable'),
      );
      expect(await service.getUnreadCount(), 0);
    },
  );
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);
  @override
  User? currentUser;
  late final StreamController<User?> changes =
      StreamController<User?>.broadcast(
        onListen: () {
          scheduleMicrotask(() => changes.add(currentUser));
        },
      );
  @override
  Stream<User?> idTokenChanges() => changes.stream;
  Future<void> close() => changes.close();
}

// Pure service tests drive the real periodic callback without widget fake time
// or waiting 60 seconds. Production Timer.periodic remains unchanged.
class _RefreshTimer implements Timer {
  _RefreshTimer(this.interval, this.callback);
  final Duration interval;
  final void Function(Timer) callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  @override
  void cancel() => isActive = false;
  void fire() {
    if (!isActive) return;
    tick++;
    callback(this);
  }
}

StreamSubscription<int> _listen(
  NoticeFirestoreService service,
  List<int> values,
  List<_RefreshTimer> timers,
) => runZoned(
  () {
    final stream = service.streamUnreadCount();
    expect(stream.isBroadcast, false);
    return stream.listen(values.add);
  },
  zoneSpecification: ZoneSpecification(
    createPeriodicTimer: (self, parent, zone, interval, callback) {
      final timer = _RefreshTimer(interval, callback);
      timers.add(timer);
      return timer;
    },
  ),
);
Future<void> _flush() => Future<void>.delayed(Duration.zero);
