import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

final securityNotificationNavigatorKey = GlobalKey<NavigatorState>();

class SecurityNotificationRouter {
  const SecurityNotificationRouter._();

  static Future<void> handle(HominodeNotificationPayload payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore
          .collection('securityStaff')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server)),
      firestore
          .collection('notifications')
          .doc(payload.entityId)
          .get(const GetOptions(source: Source.server)),
    ]);
    final profile = results[0].data();
    final notification = results[1].data();
    final canonicalCommunityId = profile?['communityId'];

    final authorized =
        profile != null &&
        profile['uid'] == user.uid &&
        profile['role'] == 'security' &&
        profile['isActive'] == true &&
        canonicalCommunityId == payload.communityId &&
        notification != null &&
        notification['recipientId'] == user.uid &&
        notification['communityId'] == canonicalCommunityId &&
        notification['audience'] == 'security' &&
        notification['role'] == 'security' &&
        notification['appId'] == 'security';
    if (!authorized) return;

    securityNotificationNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/dashboard',
      (route) => false,
    );
  }
}
