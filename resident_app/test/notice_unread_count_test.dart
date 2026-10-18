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
