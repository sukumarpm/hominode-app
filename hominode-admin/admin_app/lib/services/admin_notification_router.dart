import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

import '../notifications_screen.dart';
import 'admin_tenant_context.dart';

final adminNotificationNavigatorKey = GlobalKey<NavigatorState>();

class AdminNotificationRouter {
  const AdminNotificationRouter._();

  static Future<void> handle(HominodeNotificationPayload payload) async {
    final user = FirebaseAuth.instance.currentUser;
    final tenant = AdminTenantContext.instance;
    if (user == null || tenant.communityId != payload.communityId) return;

    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore
          .collection('admins')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server)),
      firestore
          .collection('notifications')
          .doc(payload.entityId)
          .get(const GetOptions(source: Source.server)),
    ]);
    final profile = results[0].data();
    final notification = results[1].data();
    final authorizedCommunityIds = profile?['authorizedCommunityIds'];

    final authorized =
        profile != null &&
        profile['uid'] == user.uid &&
        profile['role'] == 'admin' &&
        profile['isActive'] == true &&
        authorizedCommunityIds is List &&
        authorizedCommunityIds.contains(payload.communityId) &&
        notification != null &&
        notification['recipientId'] == user.uid &&
        notification['communityId'] == payload.communityId &&
        notification['audience'] == 'admin' &&
        notification['role'] == 'admin' &&
        notification['appId'] == 'admin';
    if (!authorized) return;

    final navigator = adminNotificationNavigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }
}
