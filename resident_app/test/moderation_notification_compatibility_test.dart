import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/notice_firestore_service.dart';
import 'package:resident_app/src/services/resident_notification_router.dart';

void main() {
  test('moderation notices render in the existing private inbox and use its existing notification destination', () {
    for (final event in ['moderation_report_dismissed','moderation_post_hidden','moderation_comment_hidden']) {
      final notice = <String,dynamic>{
        'recipientId':'resident','communityId':'A','audience':'resident','role':'resident','appId':'resident',
        'type':'general','eventType':event,'title':'Community Admin decision',
        'message':'Reason: Please follow community guidelines.','createdAt':Timestamp.fromMillisecondsSinceEpoch(1760000000000),
        'isRead':false,'data':{'route':'notifications','eventType':event},
      };
      final item = NoticeFirestoreService.eventNotice('notice',notice,'resident','A');
      expect(item,isNotNull);
      expect(item!.content,'Reason: Please follow community guidelines.');
      expect(ResidentNotificationRouter.destinationForNotification(notice),ResidentNotificationDestination.notifications);
      expect(NoticeFirestoreService.eventNotice('notice',notice,'someone-else','A'),isNull);
      expect(NoticeFirestoreService.eventNotice('notice',notice,'resident','B'),isNull);
    }
  });
}
