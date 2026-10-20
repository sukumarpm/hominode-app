import 'dart:async';
import 'package:flutter/foundation.dart';
// lib/src/services/notice_firestore_service.dart
// Notice/Notification Firestore Service - Fetch notices from Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notice_model.dart';

/// Notice Firestore Service
class NoticeFirestoreService {
  // Singleton pattern
  static final NoticeFirestoreService instance =
      NoticeFirestoreService._internal();
  factory NoticeFirestoreService() => instance;
  NoticeFirestoreService._internal()
    : _noticeLoader = null,
      _readLoader = null,
      _authOverride = null,
      _inboxChangesOverride = null;
  @visibleForTesting
  NoticeFirestoreService.forTesting({
    required Future<List<NoticeModel>> Function() notices,
    required Future<bool> Function(String) isRead,
    FirebaseAuth? auth,
    Stream<void> Function(String uid)? inboxChanges,
  }) : _noticeLoader = notices,
       _readLoader = isRead,
       _authOverride = auth,
       _inboxChangesOverride = inboxChanges;
  final Future<List<NoticeModel>> Function()? _noticeLoader;
  final Future<bool> Function(String)? _readLoader;
  final FirebaseAuth? _authOverride;
  final Stream<void> Function(String uid)? _inboxChangesOverride;

  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;
  late final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  final _readChanges = StreamController<void>.broadcast();
  void refreshUnreadCount() => _readChanges.add(null);

  // Collection name
  static const String noticesCollection = 'notices';

  // ============================================================================
  // GET NOTICES
  // ============================================================================

  /// Get all active notices for current user
  /// Filters by:
  /// - isActive: true OR status: "published"
  /// - Not expired
  /// - targetFlats is empty (all flats) OR contains user's flat
  Future<List<NoticeModel>> getNotices() async {
    if (_noticeLoader != null) return _noticeLoader();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final scope = await _loadResidentScope(uid);
    if (scope == null) return [];
    final legacy = await _getLegacyNotices();
    try {
      legacy.addAll(await _eventNotifications(uid, scope.communityId));
    } catch (error) {
      debugPrint('Event inbox unavailable (${error.runtimeType}).');
    }
    final currentScope = await _loadResidentScope(uid);
    if (_auth.currentUser?.uid != uid ||
        currentScope?.communityId != scope.communityId) {
      return [];
    }
    legacy.sort((a, b) => b.publishDate.compareTo(a.publishDate));
    return legacy;
  }

  Future<List<NoticeModel>> _getLegacyNotices() async {
    try {
      if (_noticeLoader != null) return await _noticeLoader();
      print('🔵 Fetching notices from Firestore...');

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return [];
      }

      final scope = await _loadResidentScope(user.uid);
      if (scope == null) {
        print('❌ Canonical resident community/flat scope is unavailable');
        return [];
      }
      final userFlatId = scope.flatId;
      print('🔵 User flat ID: $userFlatId');

      print('🔵 Resolving tenant- and flat-scoped notice IDs...');

      // Ensure Firebase Auth has a valid ID token before invoking
      // the authenticated callable.
      final token = await user.getIdToken();

      if (token == null || token.isEmpty) {
        print('❌ Firebase Auth token is unavailable');
        return [];
      }

      print('🔐 NOTICE AUTH UID: ${user.uid}');
      print('🔐 NOTICE AUTH TOKEN AVAILABLE: true');

      final result = await _functions
          .httpsCallable('getResidentNoticeIds')
          .call();
      final response = Map<String, dynamic>.from(result.data as Map);
      if (response['communityId'] != scope.communityId ||
          response['flatId'] != scope.flatId) {
        print('❌ Trusted notice scope does not match the current profile');
        return [];
      }
      final noticeIds = (response['noticeIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet();
      final noticeDocuments = await Future.wait(
        noticeIds.map(
          (noticeId) =>
              _firestore.collection(noticesCollection).doc(noticeId).get(),
        ),
      );

      print(
        '🔵 Found ${noticeDocuments.length} authorized notices in Firestore',
      );

      final now = DateTime.now();
      final notices = <NoticeModel>[];

      for (var doc in noticeDocuments) {
        try {
          final data = doc.data();
          if (!doc.exists || data == null) continue;
          if (data['communityId'] != scope.communityId) continue;
          print('📄 Processing notice: ${doc.id}');
          print('   Raw data keys: ${data.keys.toList()}');
          print('   status: ${data['status']}');
          print('   isActive: ${data['isActive']}');

          // Check if notice is active/published
          final isActive =
              data['isActive'] == true || data['status'] == 'published';
          if (!isActive) {
            print(
              '⏭️ Skipping inactive notice: ${doc.id} (status=${data['status']}, isActive=${data['isActive']})',
            );
            continue;
          }

          // Parse dates - handle both field name variations
          DateTime? publishDate;
          DateTime? expiryDate;

          // publishDate / publishedAt
          try {
            if (data['publishDate'] != null) {
              publishDate = (data['publishDate'] as Timestamp).toDate();
              print('   publishDate: $publishDate');
            } else if (data['publishedAt'] != null) {
              publishDate = (data['publishedAt'] as Timestamp).toDate();
              print('   publishedAt: $publishDate');
            } else if (data['createdAt'] != null) {
              publishDate = (data['createdAt'] as Timestamp).toDate();
              print('   using createdAt: $publishDate');
            } else {
              publishDate = DateTime.now();
              print('   using now: $publishDate');
            }
          } catch (e) {
            print('   ⚠️ Error parsing publishDate: $e');
            publishDate = DateTime.now();
          }

          // expiryDate / expiresAt
          try {
            if (data['expiryDate'] != null) {
              expiryDate = (data['expiryDate'] as Timestamp).toDate();
              print('   expiryDate: $expiryDate');
            } else if (data['expiresAt'] != null) {
              expiryDate = (data['expiresAt'] as Timestamp).toDate();
              print('   expiresAt: $expiryDate');
            }
          } catch (e) {
            print('   ⚠️ Error parsing expiryDate: $e');
          }

          // Check if expired
          if (expiryDate != null && now.isAfter(expiryDate)) {
            print(
              '⏭️ Skipping expired notice: ${data['title'] ?? doc.id} (expired: $expiryDate)',
            );
            continue;
          }

          // Create notice model with flexible field mapping
          // Handle both 'type' and 'category' field names
          final categoryValue =
              (data['type'] as String?) ??
              (data['category'] as String?) ??
              'general';
          print('   category/type: $categoryValue');

          final targetFlats =
              (data['targetFlats'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];

          // Check if notice is for this user's flat
          // If targetFlats is empty, show to all users
          // If targetFlats has values, only show if user's flat is in the list
          if (targetFlats.isNotEmpty && !targetFlats.contains(userFlatId)) {
            print('⏭️ Skipping notice not targeted to user flat: $userFlatId');
            continue;
          }

          final notice = NoticeModel(
            id: doc.id,
            title: data['title'] as String? ?? 'Notice',
            content: data['content'] as String? ?? '',
            category: categoryValue,
            priority: data['priority'] as String? ?? 'medium',
            authorId: data['authorId'] as String? ?? '',
            authorName: data['authorName'] as String? ?? 'Admin',
            attachments:
                (data['attachments'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            publishDate: publishDate,
            expiryDate: expiryDate,
            isActive: isActive,
            targetFlats: targetFlats,
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            updatedAt:
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );

          // Add notice if it passes all filters
          notices.add(notice);
          print('✅ Added notice: ${notice.title}');
        } catch (e, stackTrace) {
          print('❌ Error parsing notice ${doc.id}: $e');
          print('   Stack trace: $stackTrace');
        }
      }

      print('✅ Returning ${notices.length} notices');

      // Sort by publish date (newest first)
      notices.sort((a, b) => b.publishDate.compareTo(a.publishDate));

      return notices;
    } catch (e, stackTrace) {
      print('❌ Error fetching notices: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  static const eventNotificationPrefix = 'notification:';

  @visibleForTesting
  static NoticeModel? eventNotice(
    String id,
    Map<String, dynamic> data,
    String uid,
    String communityId,
  ) {
    final event = data['data'];
    if (data['recipientId'] != uid ||
        data['communityId'] != communityId ||
        data['audience'] != 'resident' ||
        data['role'] != 'resident' ||
        data['appId'] != 'resident' ||
        data['type'] != 'event' ||
        data['eventType'] != 'community_event_created' ||
        event is! Map ||
        event['route'] != 'events' ||
        event['eventId'] is! String ||
        (event['eventId'] as String).isEmpty ||
        (event['eventId'] as String).contains('/')) {
      return null;
    }
    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return NoticeModel(
      id: '$eventNotificationPrefix$id',
      eventId: event['eventId'],
      communityId: communityId,
      title: data['title'] as String? ?? '',
      content: data['message'] as String? ?? '',
      category: 'event',
      authorId: '',
      authorName: 'Admin',
      publishDate: date,
      createdAt: date,
      updatedAt: date,
    );
  }

  Future<List<NoticeModel>> _eventNotifications(
    String uid,
    String communityId,
  ) async {
    final result = await _eventInboxQuery(uid, communityId).get();
    return result.docs
        .map((doc) => eventNotice(doc.id, doc.data(), uid, communityId))
        .whereType<NoticeModel>()
        .toList();
  }

  Query<Map<String, dynamic>> _eventInboxQuery(
    String uid,
    String communityId,
  ) => _firestore
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .where('communityId', isEqualTo: communityId)
      .where('audience', isEqualTo: 'resident')
      .where('role', isEqualTo: 'resident')
      .where('appId', isEqualTo: 'resident');

  /// A scoped change signal, never an independently counted second inbox.
  /// Home replaces this subscription when its resident/community key changes.
  Stream<void> _watchEventInbox(String uid) async* {
    final scope = await _loadResidentScope(uid);
    if (scope == null || _auth.currentUser?.uid != uid) return;
    yield* _eventInboxQuery(uid, scope.communityId).snapshots().map((_) {});
  }

  /// Stream notices (real-time updates)
  Stream<List<NoticeModel>> streamNotices() {
    return Stream.fromFuture(getNotices());
  }

  Future<_ResidentNoticeScope?> _loadResidentScope(String uid) async {
    try {
      final profile = await _firestore.collection('users').doc(uid).get();
      final data = profile.data();
      if (!profile.exists || data == null) return null;

      final communityId = data['communityId']?.toString().trim() ?? '';
      final flatId = data['flatId']?.toString().trim() ?? '';
      if (communityId.isEmpty || flatId.isEmpty) return null;

      return _ResidentNoticeScope(communityId: communityId, flatId: flatId);
    } catch (e) {
      print('⚠️ Could not resolve canonical resident notice scope: $e');
      return null;
    }
  }

  // ============================================================================
  // MARK AS READ (Optional - for future use)
  // ============================================================================

  /// Mark notice as read for current user
  /// This creates a read receipt in a subcollection
  Future<void> markAsRead(String noticeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (noticeId.startsWith(eventNotificationPrefix)) {
        await _firestore
            .collection('notifications')
            .doc(noticeId.substring(eventNotificationPrefix.length))
            .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
        refreshUnreadCount();
        return;
      }
      await _firestore
          .collection(noticesCollection)
          .doc(noticeId)
          .collection('readBy')
          .doc(user.uid)
          .set({'readAt': FieldValue.serverTimestamp(), 'userId': user.uid});

      _readChanges.add(null);
    } catch (e) {
      print('❌ Error marking notice as read: $e');
    }
  }

  /// Check if notice has been read by current user
  Future<bool> isRead(String noticeId) async {
    try {
      if (_readLoader != null) return await _readLoader(noticeId);
      final user = _auth.currentUser;
      if (user == null) return false;

      if (noticeId.startsWith(eventNotificationPrefix)) {
        final doc = await _firestore
            .collection('notifications')
            .doc(noticeId.substring(eventNotificationPrefix.length))
            .get();
        return doc.data()?['isRead'] == true;
      }
      final doc = await _firestore
          .collection(noticesCollection)
          .doc(noticeId)
          .collection('readBy')
          .doc(user.uid)
          .get();

      return doc.exists;
    } catch (e) {
      print('Notice read status unavailable (${e.runtimeType}).');
      rethrow;
    }
  }

  /// Same authorized notice source and persisted read receipts as the inbox.
  /// Refresh on scoped inbox changes, successful reads and periodic fallback.
  /// Cold single-consumer stream: call again after cancellation, not listen again.
  Stream<int> streamUnreadCount() {
    late StreamController<int> controller;
    StreamSubscription<void>? reads;
    StreamSubscription<User?>? auth;
    StreamSubscription<void>? inbox;
    var binding = 0;
    Timer? timer;
    var epoch = 0;
    Future<void> refresh() async {
      final request = ++epoch, uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (!controller.isClosed) controller.add(0);
        return;
      }
      final count = await getUnreadCount();
      if (!controller.isClosed &&
          request == epoch &&
          uid == _auth.currentUser?.uid)
        controller.add(count);
    }

    Future<void> bindInbox() async {
      final currentBinding = ++binding;
      ++epoch;
      if (!controller.isClosed) controller.add(0);
      final previous = inbox;
      inbox = null;
      await previous?.cancel();
      if (controller.isClosed || currentBinding != binding) return;
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final changes =
            _inboxChangesOverride?.call(uid) ??
            (_noticeLoader == null ? _watchEventInbox(uid) : null);
        inbox = changes?.listen(
          (_) => unawaited(refresh()),
          onError: (Object error, StackTrace stack) {
            if (!controller.isClosed && currentBinding == binding) {
              ++epoch;
              controller.add(0);
              debugPrint('Unread inbox unavailable (${error.runtimeType}).');
            }
          },
        );
      }
      unawaited(refresh());
    }

    controller = StreamController<int>(
      onListen: () {
        controller.add(0);
        reads = _readChanges.stream.listen((_) => unawaited(refresh()));
        auth = _auth.idTokenChanges().listen((_) => unawaited(bindInbox()));
        timer = Timer.periodic(
          const Duration(seconds: 60),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () async {
        ++binding;
        ++epoch;
        timer?.cancel();
        await reads?.cancel();
        await auth?.cancel();
        await inbox?.cancel();
      },
    );
    return controller.stream;
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final notices = await getNotices();
      int unreadCount = 0;

      // A failed receipt is unknown, not unread. It must not suppress other
      // independently verified unread items, including canonical event records.
      for (final id in notices.map((notice) => notice.id).toSet()) {
        try {
          if (!await isRead(id)) unreadCount++;
        } catch (error) {
          debugPrint('Unread receipt unavailable (${error.runtimeType}).');
        }
      }

      return unreadCount;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }
}

class _ResidentNoticeScope {
  const _ResidentNoticeScope({required this.communityId, required this.flatId});

  final String communityId;
  final String flatId;
}
