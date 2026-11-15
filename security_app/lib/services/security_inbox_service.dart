import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/security_user_model.dart';
import 'auth_service.dart';

class SecurityInboxNotification {
  const SecurityInboxNotification(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get title => data['title'] is String
      ? data['title'] as String
      : 'Community notification';
  String get message => data['message'] is String
      ? data['message'] as String
      : data['body'] is String
      ? data['body'] as String
      : '';
  bool get isRead => data['isRead'] == true;
  DateTime? get createdAt => data['createdAt'] is Timestamp
      ? (data['createdAt'] as Timestamp).toDate()
      : null;
}

abstract interface class SecurityInbox {
  Stream<List<SecurityInboxNotification>> watch();
  Future<void> markRead(SecurityInboxNotification notification);
}

/// The same recipient fields enforced by /notifications Firestore rules.
Map<String, String> securityInboxFilters(SecurityUserModel profile) => {
  'communityId': profile.communityId,
  'recipientId': profile.uid,
  'audience': 'security',
  'role': 'security',
  'appId': 'security',
};

abstract interface class SecurityInboxStore {
  Stream<List<SecurityInboxNotification>> watch(Map<String, String> filters);
  Future<SecurityInboxNotification> get(String id);
  Future<void> markRead(String id);
}

class _FirestoreInboxStore implements SecurityInboxStore {
  _FirestoreInboxStore(this.db);
  final FirebaseFirestore db;
  @override
  Stream<List<SecurityInboxNotification>> watch(Map<String, String> filters) {
    Query<Map<String, dynamic>> query = db.collection('notifications');
    for (final filter in filters.entries) {
      query = query.where(filter.key, isEqualTo: filter.value);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SecurityInboxNotification(doc.id, doc.data()))
          .toList(),
    );
  }

  @override
  Future<SecurityInboxNotification> get(String id) async {
    final doc = await db
        .collection('notifications')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) throw StateError('Notification no longer exists.');
    return SecurityInboxNotification(doc.id, doc.data()!);
  }

  @override
  Future<void> markRead(String id) =>
      db.collection('notifications').doc(id).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}

class SecurityInboxService implements SecurityInbox {
  SecurityInboxService({AuthService? auth, SecurityInboxStore? store})
    : _auth = auth ?? AuthService(),
      _store = store ?? _FirestoreInboxStore(FirebaseFirestore.instance);
  final AuthService _auth;
  final SecurityInboxStore _store;

  bool _matches(SecurityInboxNotification row, SecurityUserModel profile) =>
      securityInboxFilters(
        profile,
      ).entries.every((e) => row.data[e.key] == e.value);

  @override
  Stream<List<SecurityInboxNotification>> watch() {
    late StreamController<List<SecurityInboxNotification>> controller;
    StreamSubscription<dynamic>? identity, records;
    var version = 0;
    controller = StreamController<List<SecurityInboxNotification>>(
      onListen: () {
        identity = _auth.authStateChanges.listen(
          (user) async {
            final current = ++version;
            if (current > 1) {
              controller.addError(
                StateError(
                  'Your Security session changed. Verifying notification access…',
                ),
              );
            }
            await records?.cancel();
            if (current != version) return;
            // Invalidate old results immediately when the authenticated identity changes.
            try {
              if (user == null) throw StateError('Please sign in again.');
              final profile = await _auth.requireSecurityProfile();
              if (current != version) return;
              if (!profile.isValidSecurityProfile ||
                  profile.uid != user.uid ||
                  _auth.currentUser?.uid != profile.uid) {
                throw StateError(
                  'Your Security session changed. Reopen Notifications.',
                );
              }
              records = _store
                  .watch(securityInboxFilters(profile))
                  .listen(
                    (rows) {
                      if (current != version) return;
                      if (_auth.currentUser?.uid != profile.uid) {
                        controller.addError(
                          StateError('Please sign in again.'),
                        );
                        return;
                      }
                      final safe =
                          rows
                              .where(
                                (r) =>
                                    _matches(r, profile) &&
                                    r.data['deletedAt'] == null,
                              )
                              .toList()
                            ..sort(
                              (a, b) =>
                                  (b.createdAt?.millisecondsSinceEpoch ?? 0)
                                      .compareTo(
                                        a.createdAt?.millisecondsSinceEpoch ??
                                            0,
                                      ),
                            );
                      controller.add(safe);
                    },
                    onError: (Object error) {
                      if (current == version) controller.addError(error);
                    },
                  );
            } catch (error) {
              if (current == version) controller.addError(error);
            }
          },
          onError: (Object error) {
            version++;
            records?.cancel();
            controller.addError(error);
          },
        );
      },
      onCancel: () async {
        version++;
        await identity?.cancel();
        await records?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> markRead(SecurityInboxNotification notification) async {
    final profile = await _auth.requireSecurityProfile();
    final record = await _store.get(notification.id);
    if (_auth.currentUser?.uid != profile.uid || !_matches(record, profile)) {
      throw StateError('Notification access denied.');
    }
    await _store.markRead(record.id);
  }
}

String securityInboxError(Object error) {
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Notification access denied. Reopen this screen or contact your Community Admin.';
    }
    if (error.code == 'failed-precondition') {
      return 'Notifications are unavailable. Ask support to check the Firestore query indexes.';
    }
  }
  if (error is StateError) return error.message.toString();
  return 'Unable to load or update notifications. Check your connection and retry.';
}
